# pkg-tr
Library similar to the Unix tr utility.

Translates strings using a mapping between ASCII characters.

Non-ASCII characters can be removed, or left untouched, but not otherwise mapped between.

# Examples
```
  tr := Tr "a-z" "A-Z"
  tr.tr "hello!"                              // Evaluates to "HELLO!"
  rot13 := Tr "a-zA-Z" "n-za-mN-ZA-M"
  rot13.tr "Hello!"                           // Evaluates to "Uryyb!"
  dasher := Tr "a-zA-Z" "-"
  dasher.tr "Hello, Wørld!"                   // Evaluates to "-----, -ø---!"
  simplifier :=
      Tr --delete --complement "a-zA-Z0-9._-"
  simplifier.tr "Tricky æøå \\ / \0.txt"      // Evaluates to "Tricky.txt"
  non_ascii_remover :=
      Tr --complement --delete "\0-\x7f"
  bytes := #['A', 0x80, 0xff, 'b', 0xe0, 'c']
  non_ascii_remover.tr bytes                  // Evaluates to "Abc"
```
