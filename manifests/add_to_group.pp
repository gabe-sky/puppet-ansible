# Declare this defined type on a target machine and it will be added to a
# group on your controllers.  In fact, the ansible::target class declares this
# defined type to add all targets to the "puppetized" group.

define ansible::add_to_group (
  String $group_name = $title,
) {

  # The inventory file is described as "ini-file like" -- and it's got sections
  # alright, but only keys, no values.  We can set the separator to a couple
  # spaces, let value default to undef, and get something Ansible is okay with.
  @@ini_setting { "add ${::fqdn} to '${group_name}' ansible group":
    ensure            => present,
    path              => '/etc/ansible/hosts',
    section           => $group_name,
    setting           => $::fqdn,
    key_val_separator => '  ',
  }

}
