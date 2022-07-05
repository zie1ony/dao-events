# Call paramenters.
NODE_ADDRESS := "--node-address http://3.140.179.157:7777"
CHAIN_NAME := "--chain-name integration-test"
DEPLOY_COMMON_PARAMS := NODE_ADDRESS + " " + CHAIN_NAME

# casper-client commands.
CLIENT_GET_STATE_ROOT_HASH := "casper-client get-state-root-hash " + NODE_ADDRESS 
CLIENT_GET_ACCOUNT := "casper-client get-account-info " + NODE_ADDRESS
CLIENT_GET_BALANCE := "casper-client get-balance " + NODE_ADDRESS
CLIENT_GET_DICTIONARY_ITEM := "casper-client get-dictionary-item " + NODE_ADDRESS 
CLIENT_GET_DEPLOY := "casper-client get-deploy " + NODE_ADDRESS 
CLIENT_QUERY := "casper-client query-global-state " + NODE_ADDRESS
CLIENT_TRANSFER := "casper-client transfer " + DEPLOY_COMMON_PARAMS
CLIENT_DEPLOY := "casper-client put-deploy " + DEPLOY_COMMON_PARAMS

# Main account.
PUBLIC_KEY_HEX := `cat integration-keys/public_key_hex`
SECRET_KEY := "integration-keys/secret_key.pem"

# Faucet account.
FAUCET_SECRET_KEY := "integration-keys2/secret_key.pem"

# Variable repository.
REPO_WASM := "variable_repository_contract.wasm"
REPO_PACKAGE_HASH_NAMED_KEY := "variable_repository_contract_package_hash"

default:
    just --list

account-info:
    {{CLIENT_GET_ACCOUNT}} --public-key {{PUBLIC_KEY_HEX}}

account-main-purse:
    just account-info | jq -r ".result.account.main_purse" 

account-balance:
    {{CLIENT_GET_BALANCE}} \
        --purse-uref `just account-main-purse` \
        --state-root-hash `just state-root-hash` \
        | jq -r ".result.balance_value"

state-root-hash:
    {{CLIENT_GET_STATE_ROOT_HASH}} | jq -r ".result.state_root_hash"

event-item-key-hash key:
    cd parser && cargo run --release "to-dictionary-item-key" {{key}}

# event-item-key-hash key:
#     cd parser && cargo run --release "to-dictionary-item-key" {{key}}

transfer-cspr:
    {{CLIENT_TRANSFER}} \
        --amount 1000000000000 \
        --secret-key {{FAUCET_SECRET_KEY}} \
        --target-account {{PUBLIC_KEY_HEX}} \
        --transfer-id 1 \
        --payment-amount 100000

deploy-repo:
    {{CLIENT_DEPLOY}} \
        --secret-key {{SECRET_KEY}} \
        --session-path {{REPO_WASM}} \
        --payment-amount 101000000000

repo-contract-hash:
    {{CLIENT_QUERY}} \
        --state-root-hash `just state-root-hash` \
        --key "{{PUBLIC_KEY_HEX}}" \
        -q {{REPO_PACKAGE_HASH_NAMED_KEY}} \
        | jq -r ".result.stored_value.ContractPackage.versions[0].contract_hash" \
        | sed s/contract/hash/

repo-contract-info:
    {{CLIENT_QUERY}} \
        --state-root-hash `just state-root-hash` \
        --key `just repo-contract-hash`

repo-contract-events-uref:
    {{CLIENT_QUERY}} \
        --state-root-hash `just state-root-hash` \
        --key `just repo-contract-hash` \
        | jq -r ".result.stored_value.Contract.named_keys[] | select( .name == \"events\") | .key"

repo-contract-event number:
    {{CLIENT_GET_DICTIONARY_ITEM}} \
        --state-root-hash `just state-root-hash` \
        --contract-hash `just repo-contract-hash` \
        --dictionary-name events \
        --dictionary-item-key `just event-item-key-hash {{number}}` \
        | jq -r ".result.stored_value.CLValue.bytes"

repo-contract-events-count:
    {{CLIENT_QUERY}} \
        --state-root-hash `just state-root-hash` \
        --key `just repo-contract-hash` \
        -q "events_length" \
        | jq ".result.stored_value.CLValue.parsed"

repo-contract-parse-event number:
    cd event-parser && cargo run --release `just repo-contract-event {{number}}`

repo-contract-wasm-deploy:
    {{CLIENT_GET_DEPLOY}} -vv \
        "27dbddcb293d0808d6d19bd235c57e5cd5af1c156a578e71cd4a94af3a4481a2" \
        | awk -F "Received successful response:" '{print $1}'

repo-contract-parse-first-event-from-processing-results:
    echo `just repo-contract-wasm-deploy` \
    | jq -r ".result.execution_results[0].result.Success.effect.transforms[] | select( .key == \"dictionary-5a0ecec0ac3e7bd8e327e290ed61ac7a6b2d7b9c3ded6eeaaee4fea9b9e34add\") | .transform.WriteCLValue.bytes"

repo-contract-parse-first-event:
    cd parser && cargo run --release "parse-full-event-bytes" `just repo-contract-parse-first-event-from-processing-results`
        
# --key "uref-494a7cccc18a1414715008dd9550e8e03ab1746ac7dfa7c4db3e39460d9c8151-007"

# casper-client get-dictionary-item --node-address http://3.140.179.157:7777 --state-root-hash `just state-root-hash` --contract-hash `just repo-contract-hash` 
#   "11da6d1f761ddf9bdb4c9d6e5303ebd41f61858d0a5647a1a7bfe089bf921be9"

# {
#     "key": "dictionary-5a0ecec0ac3e7bd8e327e290ed61ac7a6b2d7b9c3ded6eeaaee4fea9b9e34add",
#     "transform": {
#         "WriteCLValue": {
#             "bytes": "3600000001310000000c0000004f776e65724368616e676564003b4ffcfb21411ced5fc1560c3f6ffed86f4885e5ea05cde49d90962a48a14d950d0e0320000000494a7cccc18a1414715008dd9550e8e03ab1746ac7dfa7c4db3e39460d9c81514000000031316461366431663736316464663962646234633964366535333033656264343166363138353864306135363437613161376266653038396266393231626539",
#             "cl_type": "Any",
#             "parsed": null
#         }
#     }
# }
