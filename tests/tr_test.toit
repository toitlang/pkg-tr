// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import tr show *

main:
  // Test unmentioned characters are unchanged.
  tr := Tr "abc" "cba"
  expect_equals "hello" (tr.tr "hello")
  expect_equals "Hello, World!" (tr.tr "Hello, World!")
  // Test ranges.
  tr = Tr "a-z" "A-Z"
  expect_equals "HELLO" (tr.tr "hello")
  expect_equals "HELLO, WORLD!" (tr.tr "Hello, World!")
  // Test ranges that don't match up in the from and to strings.
  tr = Tr "a-cd" "ij-l"
  expect_equals "ijklefghijkl" (tr.tr "abcdefghijkl")
  // Test when the to-string runs out.
  tr = Tr "a-cd" "i"
  expect_equals "iiiiefghijkl" (tr.tr "abcdefghijkl")
  // Test we can start or end with a literal dash.
  tr = Tr "-0-9" ".a-j"
  expect_equals "from a.h" (tr.tr "from 0-7")
  tr = Tr "0-9-" "a-j."
  expect_equals "from a.h" (tr.tr "from 0-7")
  tr = Tr "0-" "a."
  expect_equals "from a.7" (tr.tr "from 0-7")
  tr = Tr "a-z" "A-"
  expect_equals "A-+-" (tr.tr "ab+z")
  tr = Tr "a-z." "A-Z-"
  expect_equals "AB-Z" (tr.tr "ab.z")
  // Test non-ASCII is left unchanged.
  tr = Tr "A-Z" "a-z"
  expect_equals "sØen sÅ sÆr ud" (tr.tr "SØEN SÅ SÆR UD")
  // Test input can be a ByteArray
  expect_equals "hello!" (tr.tr #['H', 'e', 'l', 'l', 'o', '!'])

  // Test complemented ranges.
  tr = Tr --complement "a-zA-Z " "*"
  expect_equals "The answer is ***" (tr.tr "The answer is 42!")
  // Utf-8 sequences can be replaced with multiple replacement chars.
  expect_equals "S**en s** s**r ud*" (tr.tr "Søen så sær ud!")

  // Test squeeze.
  tr = Tr --squeeze "a-c" "zy"
  expect_equals ".z.y.z.y.z.y" (tr.tr ".a.c.aa.cc.az.cy")
  tr = Tr --squeeze "a-z" "zy"
  expect_equals "Søy yå yæy y" (tr.tr "Søen så sær ud")

  // Test complement and squeeze.
  tr = Tr --complement --squeeze "a-c" "zy"
  expect_equals "yaycyaayccyaycy" (tr.tr ".a.c.aa.cc.az.cy")
  // With complement and squeeze we can replace arbitrary UTF-8 sequences with
  // a single asterisk.
  tr = Tr --complement --squeeze "A-Za-z " "*"
  expect_equals "S*en s* s*r ud*" (tr.tr "Søen så sær ud!")

  // Test delete.
  tr = Tr --delete "a-c"
  expect_equals ".....z.y" (tr.tr ".a.c.aa.cc.az.cy")
  tr = Tr --delete "a-z"
  expect_equals "Sø å æ " (tr.tr "Søen så sær ud")

  // Test delete complemented.
  tr = Tr --delete --complement "a-c"
  expect_equals "acaaccac" (tr.tr ".a.c.aa.cc.az.cy")
  tr = Tr --delete --complement "a-z"
  expect_equals "enssrud" (tr.tr "Søen så sær ud")

  // Test delete and squeeze.
  tr = Tr --delete --squeeze "a-c" "."
  expect_equals ".z.y" (tr.tr ".a.c.aa.cc.az.cy")
  expect_equals ".æ.ø" (tr.tr ".a.c.aa.cc.aæ.cø")
  expect_equals "" (tr.tr "abc")

  // Test delete and squeeze, complemented.
  tr = Tr --complement --delete --squeeze "a-c" "a"
  expect_equals "acaccac" (tr.tr ".a.c.aa.cc.az.cy")
  tr = Tr --complement --delete --squeeze "a-z" "s"
  expect_equals "ensrud" (tr.tr "Søen så sær ud!")
  expect_equals "" (tr.tr "./=")

  // Verify that we can strip all UTF-8 including malformed UTF-8.
  tr = Tr --complement --delete "\0-\x7f"
  expect_equals "Sen s sr ud!" (tr.tr "Søen så sær ud!")
  expect_equals "Abc" (tr.tr #['A', 0x80, 0xff, 'b', 0xe0, 'c'])

  // Examples from documentation.
  tr = Tr "a-z" "A-Z"
  expect_equals "HELLO!" (tr.tr "hello!")
  rot13 := Tr "a-zA-Z" "n-za-mN-ZA-M"
  expect_equals "Uryyb!" (rot13.tr "Hello!")
  dasher := Tr "a-zA-Z" "-"
  expect_equals "-----, -ø---!" (dasher.tr "Hello, Wørld!")
  simplifier := Tr --delete --complement "a-zA-Z0-9._-"
  expect_equals "Tricky.txt" (simplifier.tr "Tricky æøå \\ / \0.txt")

  expect_throw "With --delete a destination argument is not needed": Tr --delete --complement "foo" "bar"
  expect_throw "With --delete a destination argument is not needed": Tr --delete "foo" "bar"
  expect_throw "With --squeeze a destination argument is needed": Tr --delete --squeeze "foo"
  expect_throw "Need at least one char to transform to": Tr --squeeze "foo" ""
