# DAO Events

## Event storage

Every contract has its own dictionary called `events`.
All events are put there in a form of `Option<Vec<u8>>`.
In addition every contract has `events_length` named key of type `u32`.
It tracks how many events is in the dictionary.

Example:
```json
"named_keys": [
    {
        "key": "uref-494a7cccc18a1414715008dd9550e8e03ab1746ac7dfa7c4db3e39460d9c8151-007",
        "name": "events"
    },
    {
        "key": "uref-17ed743b949db06fd9e3342fa561a42b3d03b82775fc1fe9e9e793dec09e1dff-007",
        "name": "events_length"
    },
    ...
]
```

It is important to know the `events`'s URef. It will be explaind later.

## Parsing bytes from processing results.

Parser should know ahead of time how events should look like.

This is the example event we use for demostration:

```rust
pub struct OwnerChanged {
    pub new_owner: Address,
}
```

Now let's assume that we got this from processing results:
```json
{
    "key": "dictionary-5a0ecec0ac3e7bd8e327e290ed61ac7a6b2d7b9c3ded6eeaaee4fea9b9e34add",
    "transform": {
        "WriteCLValue": {
            "bytes": "3600000001310000000c0000004f776e65724368616e676564003b4ffcfb21411ced5fc1560c3f6ffed86f4885e5ea05cde49d90962a48a14d950d0e0320000000494a7cccc18a1414715008dd9550e8e03ab1746ac7dfa7c4db3e39460d9c81514000000031316461366431663736316464663962646234633964366535333033656264343166363138353864306135363437613161376266653038396266393231626539",
            "cl_type": "Any",
            "parsed": null
        }
    }
}
```

Those raw bytes `3600...6539` can be decoded in the following way:

```rust
// Extract CLValue.
let (cl_value, rem): (CLValue, _) = FromBytes::from_bytes(&bytes).unwrap();

// Parse CLValue into a Vec<u8>
let bytes: Option<Vec<u8>> = cl_value.into_t().unwrap();
let bytes = bytes.unwrap();

// Try to extract String from bytes. It will be a name of the event.
let (event_name, bytes): (String, _) = FromBytes::from_bytes(&bytes).unwrap();

// Because we know what to expect the name can be matched.
match event_name.as_str() {
    "OwnerChanged" => {
        // We know what are the fields of the event, so those can be extracted
        // one by one.
        let (_address, bytes): (Address, _) = FromBytes::from_bytes(bytes).unwrap();
        // After the extraction no more bytes to parse should left.
        assert_is_empty(bytes);
    },

    _ => panic!("Unknown event: {}", event_name)
};
```

It is also necessary to check if the event was thrown from this very contract.
After `CLValue`, `URef` can be found.
It should match `events`'s `URef`.

It can be extracted this way:
```rust
let (uref_addr, bytes): (Bytes, _) = FromBytes::from_bytes(rem).unwrap();
let uref_addr: URefAddr = uref_addr.inner_bytes().clone().try_into().unwrap();
let uref = URef::new(uref_addr, AccessRights::READ_ADD_WRITE);
```

All above can be done using `casper-js-sdk`, as it implements `CLValue`.
