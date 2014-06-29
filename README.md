# CSS Polyfills

Make CSS do more by defining simple DOM manipulations instead of ad-hoc JavaScript.

This project implements many of the CSS selectors and rules defined in [CSS3 Generated and Replaced Content Module](http://www.w3.org/TR/css3-content/) and [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/) but not supported in browsers.

## Features Overview

Some of the features are outlined below. The project has support for:

- moving content using `move-to:`
- constructing stylable DOM elements using nestable `::before`, `::after`, and `::outside` selectors
- looking up target counters and text using `target-counter(...)` and `target-text(...)`
- setting strings using `string-set:`
- manipulating attributes on elements using `x-tag-name:`, `x-attr:`, and `x-ensure-id:`
- **Clickable, Floating Footnotes** using several of the plugins above
- all the [jQuery Selector Extensions](http://api.jquery.com/category/selectors/jquery-selector-extensions/) like `:has()`, `:lt()`


# How to use on a webpage

It is easy to have the CSS Polyfills run on CSS files in the browser. Just add the following tags in `<head>`:

    <!-- You can include the styles inline... -->
    <style type="text/x-css-polyfills">
      /* Include your styles here */
    </style>

    <!-- OR, link to a CSS file -->
    <link rel="stylesheet/css-polyfills" type="text/css" href="styles.css" />

    <script src="dist.js" type="text/javascript"></script>

See [examples/browser.html](examples/browser.html) for an example.

# How to use from the command line

The easiest way to use this repo from the command line is [philschatz/css-bake.js](https://github.com/philschatz/css-bake.js).

# Installing

## Using npm or bower

You can install using npm or bower by simply running `npm install css-polyfills` or `bower install css-polyfills`.

## Building the source

Just run `npm install` and then `grunt` (from [gruntjs.org](http://gruntjs.org).


# All New Rules and Selectors

## New Selectors

- `::outside` : Creates a new element **around** the selected one (similar to `::before`)
- `::before::after` : Allows chaining of pseudoelements
- `:footnote-call` : A marker element that remains if an element is moved elsewhere in the page
- `:has(selector)` : Matches an element if elements inside it match `selector` (from jQuery)
- `:lt(num)` : Select all elements at an index less than index within the matched set (from jQuery)
- `:button`, `:checkbox`, `:eq()`, `:even`, `:file`, `:first`, `:gt()`, `:has()`, `:header`, `:hidden`, `:image`, `:input`, `:last`, `:lt()`, `:odd`, `:parent`, `:password`, `:radio`, `:reset`, `:submit`, `:text` (see [jQuery Selector Extensions](http://api.jquery.com/category/selectors/jquery-selector-extensions/) for more information)


## New Rules

- `move-to: bucket-name;` : Moves an element later in the DOM
- `string-set: string-name value...;` : Sets a string to be used later; where `value...` can include a string literal `"Hello"`, `attr(...)`, `counter(...)`, or `content(...)`
- `x-ensure-id: 'attr-name';` : Ensure the element has an attribute named `attr-name` and that it contains a unique ID (useful for footnotes)
- `x-tag-name: 'a';` : Ensure the element has a certain tag name (for making clickable pseudoelements)
- `x-attr: attr-name value...;` : Ensure the element has a certain attribute defined (for making clickable pseudoelements)

## New Content Functions

- `content: pending(bucket-name);`
- `content: string(string-name);`
- `content: target-counter(target-id, counter-name);`
- `content: target-text(target-id, limit);` where `limit` can include `attr(...)` and `content(...)`
- `content: x-target-is(target-id, selector)` is a guard function used for labeling links based on the target
- `content(...)` : The content function as defined in [CSS Generated Content for Paged Media](http://www.w3.org/TR/css3-gcpm/#setting-named-strings-the-string-set-pro) and contains one argument which may be `contents`, `before`, `after`, `first-letter`, or a selector like `"> .title"`
- `x-sort(bucket, 'optional-selector')`: Used around the `pending(...)` function to sort the elements (like for an alphabetized Glossary or Index)
- `x-parent(...)`: Used in conjunction with `attr(..)` or `content(..)` to look up the attribute or contents of a parent element


# Examples

## Moving Content

Moving content is accomplished by `move-to: bucket-name;` and `content: pending(bucket-name);` as defined in [CSS3 Generated and Replaced Content Module](http://www.w3.org/TR/css3-content/)

Example:

    // This element will be moved into the glossary-bucket...
    .def-a { move-to: bucket-a; }
    .def-b { move-to: bucket-b; }

    // ... and dumped out into this area in the order added.
    .area-a { content: pending(bucket-a); }
    .area-b { content: pending(bucket-b); }

## Nestable Pseudo Selectors and Wrapping Elements

Browsers support simple `::before` and `::after` selectors to add a single element to the DOM.
Nestable selectors allow creating elements of arbitrary complexity.

Additionally, the `::outside` selector allows wrapping an element with another for styling.

Nested selectors and `::outside` are defined in [CSS3 Generated and Replaced Content Module](http://www.w3.org/TR/css3-content/).

Example:

    h3::before::before  { content: 'Ch '; }
    h3::before          { content: counter(chap); }
    h3::before::after   { content: ': '; }
    h3::outside::before { content: '[chapter starts here]'; }

## Looking up Target Counters and Text

Browsers support simple counters in conjunction with `::before` and `::after` for numbering tables, figures, etc.

Labeling links that use those counters is trickier. For example a link that says "See Table 4.2: Sample Dataset" is not possible to describe.

Looking up the target counter value and text in a link is simple by using `target-counter(attr(href), chapter)` and `target-text(attr(href))` as defined in [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/).

Example:

    // Just set a counter so we can look it up later
    h3 { counter-increment: chap; }
    h3::before { content: 'Ch ' counter(chap) ': '; }

    .xref { content: 'See ' target-text(attr(href), content()); }

    .xref-counter {
      content: 'See Chapter ' target-counter(attr(href), chap);
    }

## Setting and Using Strings

At times it may be useful to remember a string of text and then use it later on; for example, a chapter title on the top of every page. This can be accomplished using `string-set: string-name content();` and `content: string(string-name);` defined in [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/).

Example:

    // Set a string somewhere...
    h3 { string-set: chapter-title content(); }
    // ... And then use it!
    .chap-end { content: '[End of ' string(chapter-title) ']'; }

## Clickable Footnotes

Using several of these extensions it is relatively straightforward to describe footnotes that
move to the bottom of a page and leave a clickable link in their place (as defined in [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/) ).

    .footnote {
      // Ensure the footnote has an `id` (so we can link to it)
      x-ensure-id: 'id';
      // Move it to the next `footnote-area` (page end)
      move-to: footnote-area;
      counter-increment: footnote;
    }
    // The content that is left behind after the move-to
    .footnote:footnote-call {
      // Make the stub that is left behind a link...
      x-tag-name: 'a';
      // ... whose href points to the footnote.
      x-attr: href '#' attr(id);
      content: '[###]';
      content: '[' target-counter(attr(href), footnote) ']';
    }
    // Place a number next to the actual footnote
    .footnote::before { content: counter(footnote) ': '; }

    // Define a location where the footnotes will be collected
    .footnotes { content: pending(footnote-area); }

## Custom Extensions

Additionally, it may be useful to define custom functions that manipulate the DOM.
For example, a sorted glossary at the end of a page can be described in CSS using `move-to: glossary;` and a custom function `x-sort` used in `content: x-sort(pending(glossary));`.

# Development

Make sure `bower` and `grunt` are installed in the system by running `npm install -g bower grunt`.

- Run `npm install` to install all the dependencies.
- Run `npm run develop` to download bower dependencies and build the `dist/css-polyfills.js` file
- Host this project on a static webserver like nginx or Apache or just run `./node_modules/.bin/http-server -p 8080`
