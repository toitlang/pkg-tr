// Copyright (C) 2022 Toitware ApS. All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import bitmap

/**
Inspired by the tr command line utility.
Translates strings using a mapping between ASCII characters.
Non-ASCII characters can be removed, or left untouched, but not otherwise mapped between.
*/
class Tr:
  // When deleting, a 256-entry one-zero map.
  // When mapping, a 256-entry byte map with identity values for the top 128.
  byte_array_map_ /ByteArray
  // A 256-entry ByteArray with 1 for each character that should be squeezed.
  squeeze_one_zero_map_ /ByteArray? := null
  // If this is true, the byte_array_map_ is a 256-entry ByteArray with 1 for
  // every UTF-8 code unit that should be deleted.
  delete_ /bool := false

  /// Variant of $(constructor --delete --complement --squeeze source destination).
  constructor --squeeze/bool=false source/string destination/string:
    if destination.size == 0 and source.size != 0: throw "Need at least one char to transform to"
    return Tr.private_ --squeeze=squeeze --map_utf_8_to=null source destination

  // map_utf_8_to of null, means map to themselves.
  // Otherwise it can be set to an ASCII char they should be mapped to.
  constructor.private_ --squeeze/bool=false --map_utf_8_to/int? source/string destination/string:
    byte_array_map_ = ByteArray 256: it
    squeeze_one_zero_map_ = squeeze ? (one_zero_map_ destination) : null
    f_index := 0
    t_index := 0
    f_current := -1
    t_current := -1
    f_end := -2
    t_end := -2
    while true:
      if f_end < f_current:
        if f_index == source.size: break
        f_end = f_current = source[f_index++]
        if f_index < source.size - 1 and source[f_index] == '-':
          f_end = source[f_index + 1]
          if f_end < f_current: throw "Invalid range: $source[f_index - 1..f_index + 2]"
          f_index += 2
      if t_end < t_current:
        if t_index == destination.size:
          // Last char in the destination-string just repeats as needed.
          t_end = t_current = t_current - 1
        else:
          t_end = t_current = destination[t_index++]
          if t_index < destination.size - 1 and destination[t_index] == '-':
            t_end = destination[t_index + 1]
            if t_end < t_current: throw "Invalid range: $destination[t_index - 1..t_index + 2]"
            t_index += 2
      byte_array_map_[f_current++] = t_current++
    if t_index != destination.size: throw "Too many characters in the destination string"
    if map_utf_8_to:
      byte_array_map_.fill --from=128 --to=256 map_utf_8_to

  // Gets a map from the range string, where bytes are 1 for the ASCII
  // character indexes that are in the ranges.  The non-ASCII entries
  // are zero.
  static one_zero_map_ source/string -> ByteArray:
    one_zero_map := ByteArray 256
    i := 0
    while i < source.size:
      start := source[i++]
      end := ?
      if i < source.size - 1 and source[i] == '-':
        end = source[i + 1]
        i += 2
      else:
        end = start
      if end < start: throw "Invalid range: $source[i - 1..i + 2]"
      for j := start; j <= end; j++: one_zero_map[j] = 1
    return one_zero_map

  /// Variant of $(constructor --delete --complement --squeeze source destination).
  constructor --complement/bool --squeeze/bool=false source/string destination/string:
    if destination.size == 0: throw "Need at least one char to transform to"
    // Since we are complementing, we first construct the complemented source argument.
    if not complement: return Tr --squeeze=squeeze source destination
    one_zero_map := one_zero_map_ source
    total := #[0]
    // Count the ones, where the character is not in the complemented set.
    bitmap.blit one_zero_map total 128 --destination_pixel_stride=0 --operation=bitmap.ADD
    complemented := ByteArray (128 - total[0])
    pos := 0
    if one_zero_map['-'] == 0: complemented[pos++] = '-'
    128.repeat: if it != '-' and one_zero_map[it] == 0: complemented[pos++] = it
    default /int := destination[destination.size - 1]
    // Now that we have the complemented source argument, call the constructor.
    return Tr.private_ --squeeze=squeeze --map_utf_8_to=default complemented.to_string destination

  /**
  Provide a $source set of characters that can use ranges and a $destination
    set of characters that can also use ranges.
  If there are not enough destination characters, the last one is used for the
    remaining source characters.
  A dash is normally used to indicate ASCII character ranges, but it is interpreted
    literally at the start or end of the source and destination strings.
  With $delete, the characters are deleted instead of being replaced.  In this case
    the destination argument is not needed.
  With $squeeze, any characters in the replacement ranges is squeezed.  This means
    that consecutive identical characters from the replacement set are replaced with
    a single occurrence.  This applies both to characters that were already in the
    input and to characters that appeared as a result of replacement.  When using
    squeeze, the destination argument is required, even if you are using --delete.
  With $complement, the source argument is inverted, so it applies to all characters
    not mentioned.
  Non-ASCII characters cannot be squeezed, and cannot be specified in the source
    and destination arguments.  When using --complement, the non-ASCII characters
    are implicitly mentioned at the end of the inverted range specification.
    These can only be replaced with the last character of the destination, or
    deleted, when using --delete.  When replaced they will be replaced with multiple
    replacement characters, so this makes most sense with --squeeze.
  # Examples
  ```
    tr := Tr "a-z" "A-Z"
    tr.tr "hello!"  // Evaluates to "HELLO!"
    rot13 := Tr "a-zA-Z" "n-za-mN-ZA-M"
    rot13.tr "Hello!" // Evaluates to "Uryyb!"
    dasher := Tr "a-zA-Z" "-"
    dasher.tr "Hello, Wørld!"  // Evaluates to "-----, -ø---!"
    simplifier := Tr --delete --complement "a-zA-Z0-9._-"
    simplifier.tr "Tricky æøå \\ / \0.txt"  // Evaluates to "Tricky.txt"
    non_ascii_remover := Tr --complement --delete "\0-\x7f"
    non_ascii_remover.tr #['A', 0x80, 0xff, 'b', 0xe0, 'c']  // Evaluates to "Abc"
  ```
  */
  constructor --delete/bool --complement/bool=false --squeeze/bool=false source/string destination/string?=null:
    if not delete:
      if destination == null: throw "With --delete=false a destination string must be supplied"
      return Tr --complement=complement --squeeze=squeeze source destination
    // This is a factory constructor so we tail call a regular, private constructor.
    return Tr.delete_ --complement=complement --squeeze=squeeze source destination

  constructor.delete_ --complement/bool=false --squeeze/bool=false source/string destination/string?:
    // Since we are deleting, a second argument is only for squeezing.
    if squeeze:
      if destination == null: throw "With --squeeze a destination argument is needed"
    else:
      if destination != null: throw "With --delete a destination argument is not needed"
    byte_array_map_ = one_zero_map_ source
    squeeze_one_zero_map_ = squeeze ? (one_zero_map_ destination) : null
    delete_ = true
    if complement:
      flip := #[1]
      bitmap.blit flip byte_array_map_ byte_array_map_.size --source_pixel_stride=0 --operation=bitmap.XOR

  /**
  Returns a string that is the transformed version of the $in string or ByteArray.
  May throw an error on malformed UTF-8 when given a ByteArray as input.
  */
  tr in -> string:
    out_pos := 0
    ba := ByteArray in.size
    if delete_:
      ba.replace 0 in
      in_pos := 0
      while in_pos < ba.size:
        byte := ba[in_pos++]
        if byte >= byte_array_map_.size or byte_array_map_[byte] == 0:
          ba[out_pos++] = byte
    else:
      bitmap.blit in ba ba.size --lookup_table=byte_array_map_
      out_pos = in.size
    if squeeze_one_zero_map_ and out_pos != 0:
      steps := out_pos
      out_pos = 1
      for i := 1; i < steps; i++:
        curr := ba[i]
        prev := ba[out_pos - 1]
        if squeeze_one_zero_map_[curr] == 0 or curr != prev:
          ba[out_pos++] = curr
    result := ba.to_string 0 out_pos
    return (in is string and result == in) ? in : result

/// An instance of $Tr that rot13-encodes and -decodes.
ROT13 ::= Tr "a-zA-Z" "n-za-mN-ZA-M"
