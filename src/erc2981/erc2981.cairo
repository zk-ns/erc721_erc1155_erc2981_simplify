#[starknet::contract]
mod ERC2981 {
  use traits::{ Into, TryInto, DivRem };
  use zeroable::Zeroable;
  use integer::{ U128DivRem, u128_try_as_non_zero, U16Zeroable, U128Zeroable };
  use option::OptionTrait;

  use erc721_erc1155_erc2981_simplify::erc2981::interface;

  const HUNDRED_PERCENT: u16 = 10000;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _royalties_receiver: starknet::ContractAddress,
    _royalties_percentage: u16,
  }

  //
  // IERC2981 impl
  //

  #[external(v0)]
  impl IERC2981Impl of interface::IERC2981<ContractState> {
    //support 10**38 sale_price
    fn royalty_info(self: @ContractState, token_id: u256, sale_price: u256) -> (starknet::ContractAddress, u256) {
      assert(sale_price.high.is_zero(), 'Unsupported sale price');

      let royalties_receiver_ = self._royalties_receiver.read();
      let royalties_percentage_ = self._royalties_percentage.read();

      let mut royalty_amount = 0_u256;

      if (royalties_percentage_.is_non_zero()) {
        let (q, r) = DivRem::<u128>::div_rem(
          sale_price.low,
          u128_try_as_non_zero(
            Into::<u16, felt252>::into(HUNDRED_PERCENT / royalties_percentage_).try_into().unwrap()
          ).unwrap()
        );
        royalty_amount = u256 { low: q, high: 0 };

        // if there is a remainder, we round up
        if (r.is_non_zero()) {
          royalty_amount += 1;
        }
      }

      (royalties_receiver_, royalty_amount)
    }

    // //support 10**34 sale_price
    // fn royalty_info(self: @ContractState, token_id: u256, sale_price: u256) -> (starknet::ContractAddress, u256) {
    //   assert(sale_price > 0, 'Unsupported sale price');

    //   let royalties_receiver_ = self._royalties_receiver.read();
    //   let royalties_percentage_ = self._royalties_percentage.read();

    //   let mut royalty_amount = 0_u128;
    //   let _royalties_percentage_: u128 = royalties_percentage_.into();
    //   let _sale_price: felt252 = sale_price.try_into().unwrap();
    //   let _sale_price_: u128 = _sale_price.try_into().unwrap();
    //   royalty_amount = _sale_price_ * _royalties_percentage_ / HUNDRED_PERCENT;
    //   let royalty_amount_:u256 = royalty_amount.into();
    //   (royalties_receiver_, royalty_amount_)
    // }

    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      (interface_id == interface::IERC2981_ID) 
    }
    
  }

  
  


  #[external(v0)]
  fn set_royalty_receiver(ref self: ContractState, new_receiver: starknet::ContractAddress) {
      self._set_royalty_receiver(new_receiver);
  }

  #[external(v0)]
  fn set_royalty_percentage(ref self: ContractState, new_percentage: u16) {
      self._set_royalty_percentage(new_percentage);
  }
  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn _set_royalty_receiver(ref self: ContractState, new_receiver: starknet::ContractAddress) {
      self._royalties_receiver.write(new_receiver);
    }

    fn _set_royalty_percentage(ref self: ContractState, new_percentage: u16) {
      assert(new_percentage <= HUNDRED_PERCENT, 'Invalid percentage');
      self._royalties_percentage.write(new_percentage);
    }
  }
}