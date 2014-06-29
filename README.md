### ActiveGedcom

This is a super naive parser POC for GEDCOM.

### EXAMPLE

``` bash
ruby parse.rb my-family-tree.ged > my.dot
dot -Tpng my.dot -o my.png
open my.png
```