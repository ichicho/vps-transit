names=()
types=()
ports_list=()
zone_ids=()
api_tokens=()

local_add="192.168.1.1"

names+=("foo.com")
types+=("A")
ports_list+=("80,443")
zone_ids+=("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
api_tokens+=("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")

# names+=("bar.com")
# types+=("A")
# ports_list+=("22")
# zone_ids+=("cccccccccccccccccccccccccccccccc")
# api_tokens+=("dddddddddddddddddddddddddddddddddddddddd")

beforerules_now="/etc/ufw/before.rules"
beforerules_template="/etc/ufw/before.rules.template"

nat_comment="# NAT"
config_start="# >>> Port Forwarding Config >>>"
config_end="# <<< Port Forwarding Config <<<"
records_start="# >>> DNS Records >>>"
records_end="# <<< DNS Records <<<"
rules=""
comment=""


main() {
    if "$(has_config_changed)"; then
        reconfigure
    else
        if "$(have_records_changed)"; then
            reconfigure
        fi 
    fi
}

has_config_changed() {
    if [[ $(load_ufw_config) != $(load_new_config) ]]; then
        echo true
    else
        echo false
    fi
}
load_ufw_config() {
    echo $(sed -n '/'"${config_start}"'/,/'"${config_end}"'/p' ${beforerules_now})
}
load_new_config() {
    config="${config_start}"
    for ((i=0; i<${#names[@]}; i++)); do
        config="${config}\n# ${names[i]} ${types[i]} ${ports_list[i]}"
    done
    config="${config}\n${config_end}"
    echo $(echo -e "${config}")
}

have_records_changed() {
    res=false
    for ((i=0; i<${#names[@]}; i++)); do
        name=${names[i]}
        type=${types[i]}
        zone_id=${zone_ids[i]}
        api_token=${api_tokens[i]}
        if "$(is_cf_record_different)"; then
            res=true
        fi
    done
    echo "${res}"
}
is_cf_record_different() {
    if [ $(fetch_local_record) != $(fetch_cf_record) ]; then
        echo true
    else
        echo false
    fi
}
fetch_local_record() {
    echo $(sed -n '/'"${records_start}"'/,/'"${records_end}"'/p' ${beforerules_now} | grep "${name} ${type}"  | cut -d ' ' -f 4)
}
fetch_cf_record() {
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${name}&type=${type}" \
                          -H "Content-Type: text/plain" \
                          -H "Authorization: Bearer ${api_token}") 
    echo "${response}" | sed 's/^.*"content":"\([.0-9]*\).*$/\1/'
}

reconfigure() {
    comment="${nat_comment}\n${config_start}"
    rules="*nat\n:PREROUTING ACCEPT [0:0]\n:OUTPUT ACCEPT [0:0]\n:POSTROUTING ACCEPT [0:0]"
    # Add comments for config
    for ((i=0; i<${#names[@]}; i++)); do
        comment="${comment}\n# ${names[i]} ${types[i]} ${ports_list[i]}"
    done
    comment="${comment}\n${config_end}\n${records_start}"
    # Add comments for records and rules
    for ((i=0; i<${#names[@]}; i++)); do
        name=${names[i]}
        type=${types[i]}
        ports=${ports_list[i]}
        zone_id=${zone_ids[i]}
        api_token=${api_tokens[i]}
        record=$(fetch_cf_record)
        comment="${comment}\n# ${name} ${type} ${record}"
        add_record
    done
    comment="${comment}\n${records_end}"
    rules="${rules}\nCOMMIT"
    sed 's/'"${nat_comment}"'/'"${comment}"'\n'"${rules}"'/' ${beforerules_template} > ${beforerules_now}
    reboot
}
add_record() {
    for port in ${ports//,/ }; do
        add_port
    done
}
add_port() {
    rules="${rules}\n-A PREROUTING -p tcp -d ${local_add} --dport ${port} -j DNAT --to-destination ${record}:${port}"
    rules="${rules}\n-A OUTPUT -p tcp -d ${local_add} --dport ${port} -j DNAT --to-destination ${record}:${port}"
    rules="${rules}\n-A POSTROUTING -p tcp -d ${record} --dport ${port} -j SNAT --to-source ${local_add}"
}

main
