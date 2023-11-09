const IERC2981_ID: felt252 = 0x2d3414e45a8700c29f119a54b9f11dca0e29e06ddcb214018fc37340e165ed6;

#[starknet::interface]
trait IERC2981<TContractState> {
  fn royalty_info(self: @TContractState, token_id: u256, sale_price: u256) -> (starknet::ContractAddress, u256);
  fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}