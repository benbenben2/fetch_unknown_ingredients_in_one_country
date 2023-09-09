#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::CookieJar::LWP;
use HTTP::Request::Common;
use JSON;
use utf8::all;
use Path::Tiny;

=begin
First, open this link (replace $lang by the country codes, ISO 3166):
https://$lang.openfoodfacts.org/cgi/search.pl?action=process&sort_by=last_modified_t&page_size=123&page=2&json=true

You should see something like this:
count	4856            -> total number of products in this country
page	2               -> the page that we opened (page=2 in the url)
page_count	123         -> number of products in this current page (last page (in the example, 
                           for 4856 products and 123 products per page, that would be 40) will have 
                           different number than 123 (in the example that would be 63)
page_size	123         -> number of products per page (page_size=123 in the url)
products	[…]
skip	123             -> number of products before the current page (in the example, since page 1 
                           had 123 product, the current page 2 skipped the 123 products of the page 1)

Second, set variables below.

Finally, run the code.

Result is a csv file, open it in a Spreadsheet, parse by "," (comma) only. 
Setup autofilter on the header to be able to filter on each column.
Freeze the first row to be able to scroll down and keep the header visible.

It should looks like this:
status|           lang           |occurences|product_1_url|product_2_url|
      | unrecognized ingredient  |    1    |  https...    |             |
      |    other ingredient      |    2    |  https...    |  https...   |

status is empty column that can be used to take note or while updating the taxonomies.
lang is the name of the unrecognized ingredient
occurence is the number of products having this unrecognized ingredient
next columns are the url of all the products

Number of columns depends of the occurence of unknown ingredients.

Ingredients are listed in the alphabetical order.

=cut

# setup variable
my $lang = "hr"; # jp
# tags in taxonomies "<language_code>:", ISO 639-1
my $lang_ref = "hr:"; # ja
my $count = 2849; # 4856
my $page_size = 123; # 123
# user_agent will be seen by the openfoodfacts team, 
# set something allowing them to contact you if you are querying too much the API
my $user_agent_name = 'fetch_unknown_ingredients_in_one_country.pl';

# other variable - do not change
# array in which we will compile all ingredients and the url to the product page (comma separated)
# key value, key is ingredients, value is "occurences, product url 1, product url 2, etc."
my %unknown_ingredients_in_lang;
# limit number of queries on the database to 1000 requests
my $limit_page_number = int($count) < 123000 ? sprintf "%.0f", int($count) / int($page_size) + 1 : 1000;
# define variable for query result
my $search_json;
# max number of products for same unknown ingredient, used for header
my $highest = 0;
# debug, set to 1 if needed
my $debug = 0;
if ($debug) {
    $page_size = 10;
    $limit_page_number = 10;
}


my $jar = HTTP::CookieJar::LWP->new;
my $ua = LWP::UserAgent->new(cookie_jar => $jar);
$ua->agent("fetch unknown ingredients - user: $user_agent_name/1.0");

for (my $page_nb = 1; $page_nb < $limit_page_number + 1; $page_nb++) {
    my $target_url = "https://$lang.openfoodfacts.org/cgi/search.pl?action=process&sort_by=last_modified_t&page_size=$page_size&page=$page_nb&json=true";
    if ($debug) {
        print "url: $target_url \n";
    }

    my $search = $ua->get($target_url);

    if ($search->is_success) {
        $search_json = decode_json($search->decoded_content);
    } else {
        die $search->status_line;
    }

    my $nb_of_products = scalar @{$search_json -> {products}};

    print "Number of products: $nb_of_products \n";
    my $total_products_nb = $search_json -> {count};
    print "total_page_nb: $limit_page_number - actual_page_nb: $page_nb.\n";

    for (my $i = 0; $i < $nb_of_products; $i++) {
        my $product_code = $search_json -> {products}[$i]{code};
        if ($debug) {
            print("product_code: $product_code \n");
            my $product_name = $search_json -> {products}[$i]{product_name};
            print("product_name: $product_name \n");
            my $url = $search_json -> {products}[$i]{url};
            print("product_url: $url \n");
        }

        my $product = $search_json -> {products}[$i];
        if ('ingredients' ~~ $product) {
            # get number of ingredients
            my $ingredient_array_size = scalar @{$search_json -> {products}[$i]{ingredients}};
            if ($debug) {
                print "ingredients inside \n";
                print "ingredient_array_size: $ingredient_array_size \n";
            }

            for (my $j = 0; $j < $ingredient_array_size; $j++) {
                my $ingredient_name = $search_json -> {products}[$i]{ingredients}[$j]{id};
                if ($debug) {
                    print "ingredient name: $ingredient_name \n";
                }
                if ($lang_ref eq substr($ingredient_name, 0, length($lang_ref))) {
                    if ($debug) {
                        print "found a non referenced ingredient: $ingredient_name \n";
                    }
                    # TODO: put product code as first column 
                    my $ingredient = substr($ingredient_name, length($lang_ref), );

                    # update value "2,prod_1_url,prod_2_url"
                    if ($unknown_ingredients_in_lang{$ingredient}) {
                        my $old_val = $unknown_ingredients_in_lang{$ingredient};
                        my ($old_occurence, $old_array) = split(/,/, $old_val, 2);

                        my $new_occurence = $old_occurence + 1;
                        if ($new_occurence > $highest) {
                            $highest = $new_occurence;
                        }
                        my $new_array = $old_array . ",https://$lang.openfoodfacts.org/product/$product_code";

                        $unknown_ingredients_in_lang{$ingredient} = "$new_occurence,$new_array";
                    # insert value "1,prod_1_url"
                    } else {
                        $unknown_ingredients_in_lang{$ingredient} = "1,https://$lang.openfoodfacts.org/product/$product_code";
                    }
                }
            }
        }
    }
}

sub write_file {
    # get arguments
    my ($destination, %content) = @_;

    # open output file
    my $output_file_handle = $destination->openw_utf8();

    # prepare and save header  (depend on number of occurence per ingredient)
    my $products_url_header = "";
    for (my $i = 1,; $i <= $highest; $i++) {
        $products_url_header = $products_url_header . "product_${i}_url,";
    }
    $output_file_handle->print("status,$lang,occurences,$products_url_header\n");
    
    # save in alphabetical order
    foreach my $key (sort {lc $a cmp lc $b} keys %content) {
        $output_file_handle->print(",$key,$content{$key}\n");
    }
}

# call subroutine to write in output file
my $output_dir = path(".");
my $output_file = $output_dir->child("${lang}_unknown_ingredients_output.csv");
write_file($output_file, %unknown_ingredients_in_lang);
