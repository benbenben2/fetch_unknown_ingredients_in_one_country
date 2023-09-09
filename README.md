# Fetch unknown ingredients on Open Food Facts for a specific country
## What is this script for?
In Open Food Facts, if you want to obtain a list of unknown ingredients for a specific language, go here:
https://hr.openfoodfacts.org/ingredients?status=unknown&limit=10000

This script queries Open Food Facts API to fetch the unknown ingredients for a specific country and save it as a CSV file. 

Use this script if you need the unknown ingredients list as a csv only. Otherwise, just use aforementioned page.

**Remarks**
- This script was done as a first project to learn about Perl (*i.e.*, there is room for improvements).

- There is a limit of 1'000 requests (123'000 products) to avoid impacting the API too much. This should provide a sufficiently large unknown ingredients list (my $limit_page_number).

- There is a debug mode that limit the number of requests and products per page (my $debug = 0).

## prerequisites
- Perl must be installed.
- Missing packages (see any errors that occur when you run the script) can be installed using cpan.

## update configuration
Open the following link, replacing $lang with the country code according to ISO 3166:
https://$lang.openfoodfacts.org/cgi/search.pl?action=process&sort_by=last_modified_t&page_size=123&page=2&json=true

You should see something like this:
> count	4856            -> total number of products in this country

> page	2               -> the page that we opened (page=2 in the url)

> page_count	123         -> number of products in this current page (last page (in the example, 
                           for 4856 products and 123 products per page, that would be 40) will have 
                           different number than 123 (in the example that would be 63)

> page_size	123         -> number of products per page (page_size=123 in the url)

> products	[…]

> skip	123             -> number of products before the current page (in the example, since page 1 
                           had 123 product, the current page 2 skipped the 123 products of the page 1)

Open the fetch_unknown_ingredients_in_one_country.pl and set the variables below "# setup variable"

Finally, run the code.
```
perl ./fetch_unknown_ingredients_in_one_country.pl
```

## result

Result is a CSV file. Open it in a spreadsheet, and parse it using "," (comma) as delimiter. 

Set up an autofilter on the header so that you can filter each column individually.

Freeze the first row to keep the header visible while scrolling.

It should looks like this:
```
status|           lang           |occurences|product_1_url|product_2_url|
      | unrecognized ingredient  |    1    |  http...    |             |
      |    other ingredient      |    2    |  https...   |  https...   |
```

- **status** is an empty column that you can use to take note while updating the taxonomies.
- **lang** is the name of the unrecognized ingredient.
- **occurence** is the number of products containing this unrecognized ingredient.
- next columns are the url of all the products.

Number of columns depends of the occurence of unknown ingredients.

Ingredients are listed in alphabetical order.
