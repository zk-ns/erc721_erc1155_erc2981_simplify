use array::{ ArrayTrait, SpanTrait };
use traits::{ Into, TryInto };
use option::OptionTrait;
use starknet::{
  Store,
  storage_address_from_base_and_offset,
  storage_read_syscall,
  storage_write_syscall,
  SyscallResult,
  StorageBaseAddress,
};

impl StoreSpanFelt252 of Store<Span<felt252>> {
  fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Span<felt252>> {
    StoreSpanFelt252::read_at_offset(address_domain, base, 0)
  }

  fn write(address_domain: u32, base: StorageBaseAddress, mut value: Span<felt252>) -> SyscallResult<()> {
    StoreSpanFelt252::write_at_offset(address_domain, base, 0, value)
  }

  fn read_at_offset(
    address_domain: u32,
    base: StorageBaseAddress,
    offset: u8
  ) -> SyscallResult<Span<felt252>> {
    let mut arr = array![];

    // Read span len
    let len: u8 = storage_read_syscall(:address_domain, address: storage_address_from_base_and_offset(base, offset))?
      .try_into()
      .expect('Storage - Span too large');

    // Load span content
    let mut i: u8 = offset + 1;
    loop {
      if (i > len) {
        break ();
      }

      match storage_read_syscall(:address_domain, address: storage_address_from_base_and_offset(base, i)) {
        Result::Ok(element) => {
          arr.append(element)
        },
        Result::Err(_) => panic_with_felt252('Storage - Unknown error'),
      }

      i += 1;
    };

    Result::Ok(arr.span())
  }

  fn write_at_offset(
    address_domain: u32,
    base: StorageBaseAddress,
    offset: u8,
    mut value: Span<felt252>
  ) -> SyscallResult<()> {
    // Assert span can fit in storage obj
    // 1 slots for the len; 255 slots for the span content, minus the offset
    let len: u8 = Into::<u32, felt252>::into(value.len() + offset.into()).try_into().expect('Storage - Span too large');

    // Write span content
    let mut i: u8 = offset + 1;
    loop {
      match value.pop_front() {
        Option::Some(element) => {
          storage_write_syscall(
            :address_domain,
            address: storage_address_from_base_and_offset(base, i),
            value: *element
          );
          i += 1;
        },
        Option::None(_) => {
          break ();
        },
      };
    };

    // Store span len
    Store::<felt252>::write(:address_domain, :base, value: len.into())
  }

  fn size() -> u8 {
    255
  }
}