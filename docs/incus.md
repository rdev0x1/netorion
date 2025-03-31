
# How to configure an incus client to use our vm router 

1. create the orionbr0 bridge 

```bash
> incus profile create netorion
> incus profile edit netorion

config: {}
description: Profile for containers using the orionbr0 bridge
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: orionbr0
    type: nic
name: netorion
used_by: []
project: default
```

2. Assign it to your incus container


```bash
> incus stop play
> incus profile assign play netorion
> incus start play
```

3. configure your incus netwok

Configure your network to use as gateway your vm router lan0 ip

