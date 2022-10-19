
array_splice :: (array: *[..] $T, items: []T, index: int) {
    assert(index >= 0);
    assert(index <= array.count );

    // shuffle the items in array down
    i := array.count-1;
    array_resize( array, array.count + items.count, initialize=false );
    while i > index {
        array.data[i] = array.data[i-1];
        i -= 1;
    }

    // copy the new items in
    memcpy(array.data + index, items.data, items.count * size_of(T));
}

array_extend :: (array: *[..] $T, items: []T ) {
  array_splice(array, items, array.count);
}

array_of :: (values: .. $T) -> []T #expand {
    return values;
}

