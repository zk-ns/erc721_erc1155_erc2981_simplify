#[starknet::contract]
mod ERC1155 {
  use array::{ Span, ArrayTrait, SpanTrait, ArrayDrop, SpanSerde };
  use option::OptionTrait;
  use traits::{ Into, TryInto };
  use starknet::contract_address::ContractAddressZeroable;
  use zeroable::Zeroable;
  use starknet::ContractAddress;
  use erc721_erc1155_erc2981_simplify::erc1155::interface::DualCaseSRC5DispatcherTrait;
  use erc721_erc1155_erc2981_simplify::erc1155::interface::DualCaseSRC5Dispatcher;
  use erc721_erc1155_erc2981_simplify::erc1155::interface::ERC1155ReceiverDispatcherTrait;
  use erc721_erc1155_erc2981_simplify::erc1155::interface::ERC1155ReceiverDispatcher;
  use erc721_erc1155_erc2981_simplify::storage::StoreSpanFelt252;
  use erc721_erc1155_erc2981_simplify::erc1155::interface;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _balances: LegacyMap<(u256, ContractAddress), u256>,
    _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
    _uri: Span<felt252>,
  }

  //
  // Events
  //

  #[event]
  #[derive(Drop, starknet::Event)]
  enum Event {
    TransferSingle: TransferSingle,
    TransferBatch: TransferBatch,
    ApprovalForAll: ApprovalForAll,
    URI: URI,
  }

  #[derive(Drop, starknet::Event)]
  struct TransferSingle {
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    id: u256,
    value: u256,
  }

  #[derive(Drop, starknet::Event)]
  struct TransferBatch {
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    ids: Span<u256>,
    values: Span<u256>,
  }

  #[derive(Drop, starknet::Event)]
  struct ApprovalForAll {
    account: ContractAddress,
    operator: ContractAddress,
    approved: bool,
  }

  #[derive(Drop, starknet::Event)]
  struct URI {
    value: Span<felt252>,
    id: u256,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState, uri_: Span<felt252>) {
    self.initializer(uri_);
  }
  // #[constructor]
  // fn constructor(ref self: ContractState) {
  //   self.initializer();
  // }

  //
  // IERC1155 impl
  //

  #[external(v0)]
  impl ERC1155Impl of interface::IERC1155<ContractState> {

    fn balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
      self._balances.read((id, account))
    }

    fn balance_of_batch(
      self: @ContractState,
      accounts: Span<ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
      assert(accounts.len() == ids.len(), 'ERC1155: bad accounts & ids len');

      let mut batch_balances = array![];

      let mut i: usize = 0;
      let len = accounts.len();
      loop {
        if (i >= len) {
          break ();
        }

        batch_balances.append(self.balance_of(*accounts.at(i), *ids.at(i)));
        i += 1;
      };

      batch_balances.span()
    }

    fn is_approved_for_all(
      self: @ContractState,
      owner: ContractAddress,
      operator: ContractAddress
    ) -> bool {
      self._operator_approvals.read((owner, operator))
    }

    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
      let caller = starknet::get_caller_address();

      self._set_approval_for_all(caller, operator, approved);
    }

    fn safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._safe_transfer_from(from, to, id, amount, data);
    }

    fn safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._safe_batch_transfer_from(from, to, ids, amounts, data);
    }

    fn transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._transfer_from(from, to, id, amount);
    }

    fn batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._batch_transfer_from(:from, :to, :ids, :amounts);
    }

    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      
        (interface_id == interface::IERC1155_ID) |
        (interface_id == interface::IERC1155_METADATA_ID) |
        (interface_id == interface::OLD_IERC1155_ID) |
        (interface_id == interface::ISRC6_ID)  // add to receive nft
    }

  }

  #[external(v0)]
  impl ERC1155CamelOnlyImpl of interface::IERC1155CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: starknet::ContractAddress, id: u256) -> u256{
       ERC1155Impl::balance_of(self, account, id)
    }

    fn balanceOfBatch(self: @ContractState, accounts: Span<starknet::ContractAddress>, ids: Span<u256>) -> Span<u256>{
       ERC1155Impl::balance_of_batch(self, accounts, ids)
    }

    fn isApprovedForAll(
        self: @ContractState,
        account: starknet::ContractAddress,
        operator: starknet::ContractAddress
    ) -> bool{
       ERC1155Impl::is_approved_for_all(self, account, operator)
    }

    fn setApprovalForAll(ref self: ContractState, operator: starknet::ContractAddress, approved: bool){
       ERC1155Impl::set_approval_for_all(ref self, operator, approved);
    }

    fn safeTransferFrom(
        ref self: ContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        id: u256,
        amount: u256,
        data: Span<felt252>
    ){
       ERC1155Impl::safe_transfer_from(ref self, from, to, id, amount, data);
    }

    fn safeBatchTransferFrom(
        ref self: ContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
        data: Span<felt252>
    ){
       ERC1155Impl::safe_batch_transfer_from(ref self, from, to, ids, amounts, data);
    }

    fn transferFrom(
        ref self: ContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        id: u256,
        amount: u256,
    ){
       ERC1155Impl::transfer_from(ref self, from, to, id, amount);
    }

    fn batchTransferFrom(
        ref self: ContractState,
        from: starknet::ContractAddress,
        to: starknet::ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
    ){
       ERC1155Impl::batch_transfer_from(ref self, from, to, ids, amounts);
    }

    fn supportsInterface(self: @ContractState, interface_id: felt252) -> bool {
       ERC1155Impl::supports_interface(self, interface_id)
    }
  }

  #[external(v0)]
  impl ERC1155MetadataImpl of interface::IERC1155Metadata<ContractState> {
    fn uri(self: @ContractState, token_id: u256) -> Span<felt252> {
      self._uri.read()
    }

  }

  #[external(v0)]
  fn mint(
          ref self: ContractState,
          to: ContractAddress,
          id: u256,
      ) {
        self._unsafe_mint(to, id, 1);            
      }

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(ref self: ContractState, uri_: Span<felt252>) {
      self._set_uri(uri_);
    }

    // // example, change to your own nft json url
    // fn initializer(ref self: ContractState) {
      
    //   let mut uri_ = ArrayTrait::new();
    //   uri_.append('https://ipfs.io/ipfs/bafkrei');
    //   uri_.append('cmeharxprhocrmxfdeemw7r57vid');
    //   uri_.append('hbbsuapuy7qgdnmhtxwnx7v4');
    //   self._set_uri(uri_.span());
    // }

    fn _mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256, data: Span<felt252>) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
    }

    fn _unsafe_mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(Zeroable::zero(), to, ids, amounts);
    }

    fn _mint_batch(
      ref self: ContractState,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
    }

    // Burn

    fn _burn(ref self: ContractState, from: ContractAddress, id: u256, amount: u256) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    fn _burn_batch(ref self: ContractState, from: ContractAddress, ids: Span<u256>, amounts: Span<u256>) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    // Setters

    fn _set_uri(ref self: ContractState, new_uri: Span<felt252>) {
      self._uri.write(new_uri);
    }

    fn _set_approval_for_all(
      ref self: ContractState,
      owner: ContractAddress,
      operator: ContractAddress,
      approved: bool
    ) {
      assert(owner != operator, 'ERC1155: self approval');

      self._operator_approvals.write((owner, operator), approved);

      // Events
      self.emit(
        Event::ApprovalForAll(
          ApprovalForAll { account: owner, operator, approved }
        )
      );
    }

    // Balances update

    fn _safe_update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      //update first
      self._update(from, to, ids, amounts);

      let operator = starknet::get_caller_address();

      // Safe transfer check
      if (to.is_non_zero()) {
        if (ids.len() == 1) {
          let id = *ids.at(0);
          let amount = *amounts.at(0);
          
          assert(
                self._check_on_erc1155_received(operator, from, to, id, amount, data), 'ERC1155: safe transfer failed'
            );
          
        } else {
          
          assert(
                self._check_on_erc1155_batch_received(operator, from, to, ids, amounts, data), 'batch safe transfer failed'
            );
          
        }
      }
    }

    fn _update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(ids.len() == amounts.len(), 'ERC1155: bad ids & amounts len');

      let operator = starknet::get_caller_address();

      let mut i: usize = 0;
      let len = ids.len();
      loop {
        if (i >= len) {
          break ();
        }

        let id = *ids.at(i);
        let amount = *amounts.at(i);

        // Decrease sender balance
        if (from.is_non_zero()) {
          let from_balance = self._balances.read((id, from));
          assert(from_balance >= amount, 'ERC1155: insufficient balance');

          self._balances.write((id, from), from_balance - amount);
        }

        // Increase recipient balance
        if (to.is_non_zero()) {
          let to_balance = self._balances.read((id, to));
          self._balances.write((id, to), to_balance + amount);
        }

        i += 1;
      };

      // Transfer events
      if (ids.len() == 1) {
        let id = *ids.at(0);
        let amount = *amounts.at(0);

        self.emit(
          Event::TransferSingle(
            TransferSingle { operator, from, to, id, value: amount }
          )
        );
      } else {
        self.emit(
          Event::TransferBatch(
            TransferBatch { operator, from, to, ids, values: amounts }
          )
        );
      }
    }

    // Safe transfers

    fn _safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._safe_update(from, to, ids, amounts, data);
    }

    fn _safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._safe_update(from, to, ids, amounts, data);
    }

    // Unsafe transfers

    fn _transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._update(from, to, ids, amounts);
    }

    fn _batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._update(from, to, ids, amounts);
    }

    // Safe transfer check

    fn _check_on_erc1155_received(
        self: @ContractState, operator: ContractAddress, from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5Dispatcher { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            ERC1155ReceiverDispatcher { contract_address: to }
                .on_erc1155_received(
                   operator , from, id, amount, data
                ) == interface::ON_ERC1155_RECEIVED_SELECTOR
        } else {
            DualCaseSRC5Dispatcher { contract_address: to }.supports_interface(interface::ISRC6_ID)
        }
    }

    fn _check_on_erc1155_batch_received(
        self: @ContractState, operator: ContractAddress, from: ContractAddress, to: ContractAddress, ids: Span<u256>, amounts: Span<u256>, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5Dispatcher { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            ERC1155ReceiverDispatcher { contract_address: to }
                .on_erc1155_batch_received(
                    operator, from, ids, amounts, data
                ) == interface::ON_ERC1155_BATCH_RECEIVED_SELECTOR
        } else {
            DualCaseSRC5Dispatcher { contract_address: to }.supports_interface(interface::ISRC6_ID)
        }
    }

    fn _as_singleton_spans(self: @ContractState, element1: u256, element2: u256) -> (Span<u256>, Span<u256>) {
      (array![element1].span(), array![element2].span())
    }
  }
}