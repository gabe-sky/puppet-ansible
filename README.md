
# Overview

This simple module is intended to set up basic Ansible controllers and prepare target machines to trust the controllers' SSH keys for root logins.  I wrote this quick module when I needed to learn a little about Ansible, and wanted to be able to bring controllers and targets up easily, in a sandbox, without having to do the manual set-up recommended in the docs.

This module isn't anything fancy.  The controllers all connect to targets as root, for instance.  But it's a start, and saves some time if you need to create sandboxes from time to time, rapidly.

This module gets you at least through the getting started guide's assumptions about your environment.  Namely, that root on the controller node can do passwordless SSH connections to your target hosts.  You should be able to skip to the "Your first commands" section of the getting started guide, from here.


# Use

To turn a (Redhat, currently) machine into a controller, simply classify it with `ansible::controller` and do a Puppet run on it.  This will install the packages you need, generate an SSH key for Ansible to use, and export it to your PuppetDB so that your target nodes can collect it.

To add targets to your environment, classify them with `ansible::target` and do a Puppet run on them.  They will add the controller's key to root's authorized_keys file on this run, and export resources so that the controller knows about them.

After adding targets, perform a Puppet run on the controller node(s).  This will add new targets' host keys to the known_hosts file, and will add the new targets to the "puppetized" group in Ansible's host inventory file.

You should now be able to ping all of your targets in the module-provided "puppetized" group.

```
ansible puppetized -m ping
```

To add hosts to an arbitrary inventory group, declare the `ansible::add_to_group` defined type with the title set to the name of the group you want the host to be added to.  For instance, the `ansible::target` class itself uses a declaration of `ansible::add_to_group { 'puppetized': }` to add all targets to the "puppetized" group.

The management of Ansible's host file is done with ini_setting resources, so it should be safe for you to add additional groups by hand if you feel like it.  Although, you can declare the ansible::add_to_group defined type as many times as you like on any node, to put it in multiple groups.  That's a better solution than hand-edits.

# Example

For people who like examples, here's one.  I want to be able to login to my machine 'controller001' and issue commands to my other nodes.  I have some webservers, production databases, and development databases.  If a node lacks classification, I still want it to be controllable by Ansible, and I want it to be in an inventory group so it's easy to issue commands to just those nodes that lack classification.


```
# Here is a controller node.  You could have more than one, if you like.
node 'control001' {
  include ansible::controller
  include ansible::target      # Just like Puppet masters also have agents.
}

# Here are three of my web servers.
node 'web001','web002','web003' {
  include apache
  include ansible::target
  ansible::add_to_group { 'webservers': }
}

# My production databases have a predictable naming scheme.
node /prod-db\d+/ {
  include mysql::server
  include ansible::target
  ansible::add_to_group { 'production': }
  ansible::add_to_group { 'databases': }
}

# Development databases have similarly predictable names.
node /dev-db\d+/ {
  include mysql::server
  include mysql::client
  include ansible::target
  ansible::add_to_group { 'development': }
  ansible::add_to_group { 'databases': }
}

# Finally, make unclassified nodes into targets, and group them to be obvious.
node default {
  include ansible::target
  ansible::add_to_group { "unclassified_$::osfamily": }  # Note: Using a fact
}
```

My controller001 machine will generate an SSH keypair for Ansible to use.  And it will export the corresponding public key to PuppetDB.

All of my ansible::target machines will collect the controller's public key, and authorize it to login as root.

As ansible::target machines come online, they'll export resources that indicate what groups they should be in, in the controller's inventory.  When controller001 does agent runs, it will collect these, and assemble its /etc/ansible/hosts file from them.

In my example set-up, all of the ansible::target nodes are in an inventory group called 'puppetized', simply by nature of declaring the class.  Additional ansible::add_to_group declarations add them to whatever additional groups I'd like the controllers to be able to address them as.  Check out that last one in the default node -- nothing keeps you from using facts or other variables when making ansible inventory groups!  (Think: $::datacenter, $::network, $::virtual ...)


# Limitations

Only Redhat 6 and 7 variants can be controllers, so far.  It should just be a matter of adding entries to $controller_pkglist in ansible::params, to add support for others.

I haven't tried a Debian target with SELinux enabled, so I don't know if it will need the python binding.  Currenly, I only ensure that libselinux-python is installed if I detect selinux on a Redhat variant.

Currently, the ansible::add_to_group defined type only adds things to groups, it doesn't remove them.  Since I use ini_setting and try to stay out of the way of manual edits of /etc/ansible/hosts, this is the safest thing to do.  (I could switch to having ansible's inventory be a directory, then manage individual files per group, and this feature might be safe to add.)

Currently, I only set you up to run as root on the controller, and have Ansible login as root on target machines.  It would be simple enough, I think, to make an ansible::user sort of defined type that makes a keypair for unprivileged users on the targets.  Then normal users on the controller could use Ansible, too.  There may be issues with who owns the key on the controller, though.  For instance, if targets have a 'noc' user that you'd like to login to targets as, but there isn't an actual 'noc' user on the controller.  Simple cases should be okay though.

Currently, controllers use the 'json' style of fact caching.  It would be easy to make it also configure Ansible to store facts in Redis, but I don't need anything that complex for my purposes.
