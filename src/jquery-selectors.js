// From http://stackoverflow.com/questions/2093355/nth-of-type-in-jquery-sizzle
/**
 * Return true to include current element
 * Return false to exclude current element
 */


Sizzle.selectors.pseudos['nth-of-type'] = function(elem, i, match) {
  console.log('ksajhdfskajhdfksjhdf');
  console.log(arguments);
    match[3] = match[3] == "even" ? "2n" : match[3] == "odd" ? "2n+1" : match[3];
    if (match[3].indexOf("n") === -1) return i + 1 == match[3];
    var parts = match[3].split("+");
    return (i + 1 - (parts[1] || 0)) % parseInt(parts[0], 10) === 0;
};
