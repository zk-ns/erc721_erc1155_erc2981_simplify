#[starknet::contract]
mod ERC721ROYALTIES {
    use erc721_erc1155_erc2981_simplify::erc721royalties::interface::DualCaseSRC5DispatcherTrait;
    use erc721_erc1155_erc2981_simplify::erc721royalties::interface::DualCaseSRC5Dispatcher;
    use erc721_erc1155_erc2981_simplify::erc721royalties::interface::DualCaseERC721ReceiverDispatcherTrait;
    use erc721_erc1155_erc2981_simplify::erc721royalties::interface::DualCaseERC721ReceiverDispatcher;
    use erc721_erc1155_erc2981_simplify::erc721royalties::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::ClassHash;

    const HUNDRED_PERCENT: u128 = 10000;
    

    #[storage]
    struct Storage {
        ERC721_name: felt252,
        ERC721_symbol: felt252,
        ERC721_owners: LegacyMap<u256, ContractAddress>,
        ERC721_balances: LegacyMap<ContractAddress, u256>,
        ERC721_token_approvals: LegacyMap<u256, ContractAddress>,
        ERC721_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        // ERC721_token_uri: LegacyMap<u256, felt252>,
        ERC721_total_supply: u256,
        _royalties_receiver: ContractAddress,
        _royalties_percentage: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll,
        Upgraded: Upgraded,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC721: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC721: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC721: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC721: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC721: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC721: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC721: token already minted';
        const WRONG_SENDER: felt252 = 'ERC721: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC721: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: felt252,
        symbol: felt252,
    ) {
        self.initializer(name, symbol);
        self.ERC721_total_supply.write(0);
    }

    //
    // External
    //

    #[external(v0)]
    impl ERC721Impl of interface::IERC721<ContractState> {
        
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), Errors::INVALID_ACCOUNT);
            self.ERC721_balances.read(account)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            self.ERC721_token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC721_operator_approvals.read((owner, operator))
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || ERC721Impl::is_approved_for_all(@self, owner, caller),
                Errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), Errors::UNAUTHORIZED
            );
            self._safe_transfer(from, to, token_id, data);
        }

        fn supports_interface(self: @ContractState, interface_id: felt252) -> bool{
            (interface_id == interface::IERC721_ID) |
            (interface_id == interface::IERC721_METADATA_ID) |
            (interface_id == interface::IERC2981_ID) |
            (interface_id == interface::ISRC6_ID)  // add to receive nft
        }

    }

    #[external(v0)]
    impl ERC721CamelOnlyImpl of interface::IERC721CamelOnly<ContractState> {
        
        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC721Impl::balance_of(self, account)
        }

        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721Impl::owner_of(self, tokenId)
        }

        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            ERC721Impl::get_approved(self, tokenId)
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            ERC721Impl::is_approved_for_all(self, owner, operator)
        }

        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            ERC721Impl::set_approval_for_all(ref self, operator, approved)
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            ERC721Impl::transfer_from(ref self, from, to, tokenId)
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            ERC721Impl::safe_transfer_from(ref self, from, to, tokenId, data)
        }
        
        fn supportsInterface(self: @ContractState, interface_id: felt252) -> bool{
            ERC721Impl::supports_interface(self, interface_id)
        }
    }

    #[external(v0)]
    impl ERC721MetadataImpl of interface::IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.ERC721_name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.ERC721_symbol.read()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> Array<felt252> {
            assert(self._exists(token_id), Errors::INVALID_TOKEN_ID);
            // self.ERC721_token_uri.read(token_id)
            let base_uri = self._base_uri();
            base_uri
        }
    }

    //
    // IERC721 Metadata Camel impl
    //

    #[external(v0)]
    impl ERC721MetadataCamelOnlyImpl of interface::IERC721MetadataCamelOnly<ContractState> {
        fn tokenUri(self: @ContractState, tokenId: u256) -> Array<felt252> {
            ERC721MetadataImpl::token_uri(self, tokenId)
        }
    }

    #[external(v0)]
    impl IERC2981Impl of interface::IERC2981<ContractState> {
        //support 10**34 sale_price
        fn royalty_info(self: @ContractState, token_id: u256, sale_price: u256) -> (ContractAddress, u256) {
            assert(sale_price > 0, 'Unsupported sale price');

            let royalties_receiver_ = self._royalties_receiver.read();
            let royalties_percentage_ = self._royalties_percentage.read();

            let mut royalty_amount = 0_u128;
            let _sale_price: felt252 = sale_price.try_into().unwrap();
            let _sale_price_: u128 = _sale_price.try_into().unwrap();
            royalty_amount = _sale_price_ * royalties_percentage_ / HUNDRED_PERCENT;
            let royalty_amount_:u256 = royalty_amount.into();
            (royalties_receiver_, royalty_amount_)
        }
    }

    #[external(v0)]
    impl IERC2981CamelOnlyImpl of interface::IERC2981CamelOnly<ContractState> {
        fn royaltyInfo(self: @ContractState, token_id: u256, sale_price: u256) -> (ContractAddress, u256) {
            IERC2981Impl::royalty_info(self, token_id, sale_price)
        }
    }

    #[external(v0)]
    fn mint(ref self: ContractState, to: ContractAddress){
        let id = self.ERC721_total_supply.read() + 1;
        self._mint(to, id);
    }
    
    #[external(v0)]
    fn set_royalty_receiver(ref self: ContractState, new_receiver: ContractAddress) {
        self._royalties_receiver.write(new_receiver);
    }

    #[external(v0)]
    fn set_royalty_percentage(ref self: ContractState, new_percentage: u128) {
        assert(new_percentage <= HUNDRED_PERCENT, 'Invalid percentage');
        self._royalties_percentage.write(new_percentage);
    }


    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name: felt252, symbol: felt252) {
            self.ERC721_name.write(name);
            self.ERC721_symbol.write(symbol);
        }

        fn _owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            let owner = self.ERC721_owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        fn _exists(self: @ContractState, token_id: u256) -> bool {
            !self.ERC721_owners.read(token_id).is_zero()
        }

        fn _is_approved_or_owner(
            self: @ContractState, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = ERC721Impl::is_approved_for_all(self, owner, spender);
            owner == spender
                || is_approved_for_all
                || spender == ERC721Impl::get_approved(self, token_id)
        }

        fn _approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, Errors::APPROVAL_TO_OWNER);

            self.ERC721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        fn _set_approval_for_all(
            ref self: ContractState,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, Errors::SELF_APPROVAL);
            self.ERC721_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn _mint(ref self: ContractState, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), Errors::ALREADY_MINTED);

            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);
            self.ERC721_total_supply.write(self.ERC721_total_supply.read() + 1);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            assert(!to.is_zero(), Errors::INVALID_RECEIVER);
            let owner = self._owner_of(token_id);
            assert(from == owner, Errors::WRONG_SENDER);

            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(from, self.ERC721_balances.read(from) - 1);
            self.ERC721_balances.write(to, self.ERC721_balances.read(to) + 1);
            self.ERC721_owners.write(token_id, to);

            self.emit(Transfer { from, to, token_id });
        }

        fn _burn(ref self: ContractState, token_id: u256) {
            let owner = self._owner_of(token_id);

            self.ERC721_token_approvals.write(token_id, Zeroable::zero());

            self.ERC721_balances.write(owner, self.ERC721_balances.read(owner) - 1);
            self.ERC721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        fn _safe_transfer(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._transfer(from, to, token_id);
            assert(
                _check_on_erc721_received(from, to, token_id, data), Errors::SAFE_TRANSFER_FAILED
            );
        }

        fn _base_uri(self: @ContractState) -> Array<felt252> {
            // remember to change url to your own nft json url
            let mut uri = ArrayTrait::new();
            // uri.append('https://ipfs.io/ipfs/bafkrei');
            // uri.append('cmeharxprhocrmxfdeemw7r57vid');
            // uri.append('hbbsuapuy7qgdnmhtxwnx7v4');
            uri
        }
    }

    fn _check_on_erc721_received(
      from: starknet::ContractAddress,
      to: starknet::ContractAddress,
      token_id: u256,
      data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5Dispatcher { contract_address: to }
            .supports_interface(interface::IERC721_RECEIVER_ID)) {
            DualCaseERC721ReceiverDispatcher { contract_address: to }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == interface::IERC721_RECEIVER_ID
        } else {
            DualCaseSRC5Dispatcher { contract_address: to }.supports_interface(interface::ISRC6_ID)
        }
    }
}