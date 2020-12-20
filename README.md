# vps-transit
## Purpose
Transit traffic on a vps to accelerate speed of access.

## Environment
- Ubuntu 20.04
- UFW

Use Ubuntu because UFW is the default firewall which is relatively easy to configure.

## Setup UFW
Generally follow this [guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu-20-04).

### Install UFW
```
$ sudo apt update
$ sudo apt install ufw 
```

### Apply UFW with IPv6
Check whether value of `IPv6` is set to `yes` in `/etc/default/ufw`. If not, change to `yes` if you want to use UFW with IPv6.
```
$ sudo vim /etc/default/ufw

/etc/default/ufw
...
IPV6=yes
...
```

### Set up default policies
Basically deny all incoming connections and allow all outgoing connections.
```
$ sudo ufw default deny incoming
$ sudo ufw default allow outgoing
```

### Allow incoming connections through specific ports
Issue `sudo ufw allow <port>` to allow incoming connection to `<port>`.
```
$ sudo ufw allow ssh
$ sudo ufw allow https
$ sudo ufw allow 5000
$ sudo ufw allow 5001/tcp
```

### Enable UFW
```
$ sudo ufw enable
```

### Other useful commands
Check UFW status and rules
```
$ sudo ufw status
```
Disable UFW
```
$ sudo ufw disable
```

## Set up port forwarding
### Enable port forward
Edit `/etc/default/ufw`. Change value of `DEFAULT_FORWARD_POLICY` to `ACCEPT`.
```
$ sudo vim /etc/default/ufw

/etc/default/ufw
...
DEFAULT_FORWARD_POLICY="ACCEPT"
...
```

Edit `/etc/ufw/sysctl.conf`. Uncomment the line `#net/ipv4/ip_forward=1` to set value of `net/ipv4/ip_forward` to `1`.
```
$ sudo vim /etc/ufw/sysctl.conf

/etc/ufw/sysctl.conf
...
net/ipv4/ip_forward=1
...
```

### Set port forwarding rules
Assume you want to forward the traffic on your vps' `2222` port to destination `3.3.3.3:4444`. Confirm your vps address that port `2222` can listen on. In this case, we assume your vps address is `1.1.1.1`.

Oepn `/etc/ufw/before.rules` and add rules(from `*nat` to `COMMIT`) before the line `*filter`.

```
$ sudo vim /etc/ufw/before.rules

/etc/ufw/before.rules
...
*nat
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -d 1.1.1.1 --dport 2222 -j DNAT --to-destination 3.3.3.3:4444
-A OUTPUT -p tcp -d 1.1.1.1 --dport 2222  -j DNAT --to-destination 3.3.3.3:4444
-A POSTROUTING -p tcp -d 3.3.3.3 --dport 4444 -j SNAT --to-source 1.1.1.1
COMMIT
...
*filter
...
```
