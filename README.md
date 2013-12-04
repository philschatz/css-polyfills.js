# CSS Polyfill

Make CSS do more by defining simple DOM manipulations instead of ad-hoc JavaScript.

This project implements many of the CSS selectors and rules defined in [CSS3 Generated and Replaced Content Module](http://www.w3.org/TR/css3-content/) and [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/) but not supported in browsers.

# Features

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

Browsers support simple `:before` and `:after` selectors to add a single elemnt to the DOM.
Nestable selectors allow creating elements of arbitrary complexity.

Additionally, the `:outside` selector allows wrapping an element with another for styling.

Nested selectors and `:outside` are defined in [CSS3 Generated and Replaced Content Module](http://www.w3.org/TR/css3-content/).

Example:

    h3:before:before  { content: 'Ch '; }
    h3:before         { content: counter(chap); }
    h3:before:after   { content: ': '; }
    h3:outside:before { content: '[chapter starts here]'; }

## Looking up Target Counters and Text

Browsers support simple counters in conjunction with `:before` and `:after` for numbering tables, figures, etc.

Labeling links that use those counters is trickier. For example a link that says "See Table 4.2: Sample Dataset" is not possible to describe.

Looking up the target counter value and text in a link is simple by using `target-counter(attr(href), chapter)` and `target-text(attr(href))` as defined in [CSS3 Generated Content for Paged Media Module](http://www.w3.org/TR/css3-gcpm/).

Example:

    // Just set a counter so we can look it up later
    h3 { counter-increment: chap; }
    h3:before { content: 'Ch ' counter(chap) ': '; }

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

## Custom Extensions

Additinoally, it may be useful to define custom functions that manipulate the DOM.
For example, a sorted glossary at the end of a page can be described in CSS using `move-to: glossary;` and a custom function `x-sort` used in `content: x-sort(pending(glossary));`.

# Development

Make sure `bower` and `grunt` are installed in the system by running `npm install -g bower grunt`.

- Run `npm install` to install all the dependencies.
- Optionally run `coffee -c css-polyfill.coffee` for use in code-coverage analysis using blanket.js
- Host this project on a static webserver like nginx or Apache or just run `./node_modules/.bin/http-server -p 8080`
