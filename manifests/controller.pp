# This class sets up just enough to create Ansible controller nodes to play
# with.  Please see the README for limitations.  Namely, this class assumes you
# will run ansible commands as root, with it logging in to targets as root.

class ansible::controller (
  Boolean $manage_epel                        = true,
  Enum['json','redis','off'] $fact_caching    = 'json',
  Boolean $bail_on_debians                    = true,
  Optional[Array[String]] $controller_pkglist = $ansible::params::controller_pkglist,
) inherits ansible::params {

  # If someone wants to apply this class to a Debian-ish system, let's bail out
  # right now, unless they really know what they're doing, and have set the
  # $bail_on_debians parameter to false.
  if ( $::os['family'] == 'Debian' and $bail_on_debians == true ) {
    fail('The ansible::controller class does not work on Debian.')
  }

  # Set the defaults for all Files in this scope.
  File {
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['ansible'],
  }

  # Add the EPEL repository, if desired/needed
  if ( $manage_epel and $::os['family'] == 'RedHat' ) {
    ensure_packages('epel-release', { 'ensure' => 'installed', 'before' => Package['ansible'] })
  }

  # Install ansible and its dependencies.
  ensure_packages($controller_pkglist)

  # Create a keypair for ansible to use, and configure ansible to use it.
  file { '/etc/ansible/ssh':
    ensure => directory,
    mode   => '0700',
    before => Exec['generate ansible ssh keypair'],
  }
  exec { 'generate ansible ssh keypair':
    command => '/usr/bin/ssh-keygen -f /etc/ansible/ssh/id_rsa.ansible -t rsa -N "" -C "ansible"',
    creates => '/etc/ansible/ssh/id_rsa.ansible',
  }
  file_line { 'ansible.cfg private_key_file':
    ensure => present,
    line   => 'private_key_file = /etc/ansible/ssh/id_rsa.ansible',
    match  => 'private_key_file =',
    path   => '/etc/ansible/ansible.cfg',
  }

  # This module implements a custom fact that spots the key file, and parses out
  # the cryptographic portion.  However, it won't be able to read the file until
  # Puppet's second run.  The conditional logic avoids problems if we're just on
  # the first run ever.
  if ( $::ansible_ssh_key ) {
    @@ssh_authorized_key { "ansible controller ${::fqdn}":
      user => 'root',
      type => 'ssh-rsa',
      key  => $::ansible_ssh_key,
    }
  }

  # Collect all the ssh host keys for targets, so I don't need to say "yes."
  Sshkey <<| tag == 'ansible::target' |>>

  # Ensure the inventory file exists, and populate groups based on targets'
  # declarations of the ansible::add_to_group defined type.
  file { '/etc/ansible/hosts':
    ensure  => file,
  } ->
  Ini_setting <<| tag == 'ansible::add_to_group' |>>

  # If $fact_caching is set to 'json', let's enable it.  The redis option is
  # just forward-looking -- but doesn't currently do anything.
  if ( $fact_caching == 'redis' ) {
    notify { 'The redis cache is not yet implemented in the ansible module.': }
  }
  elsif ( $fact_caching == 'json' ) {
    file { '/etc/ansible/factcache':
      ensure => directory,
    }
    ini_setting { 'ansible.cfg gathering = smart':
      ensure  => present,
      path    => '/etc/ansible/ansible.cfg',
      section => 'defaults',
      setting => 'gathering',
      value   => 'smart',
    }
    ini_setting { 'ansible.cfg fact_caching = json':
      ensure  => present,
      path    => '/etc/ansible/ansible.cfg',
      section => 'defaults',
      setting => 'fact_caching',
      value   => 'jsonfile',
    }
    ini_setting { 'ansible.cfg fact_caching_connection = /etc/ansible/factcache':
      ensure  => present,
      path    => '/etc/ansible/ansible.cfg',
      section => 'defaults',
      setting => 'fact_caching_connection',
      value   => '/etc/ansible/factcache',
    }
    ini_setting { 'ansible.cfg fact_caching_timeout = 86400':
      ensure  => present,
      path    => '/etc/ansible/ansible.cfg',
      section => 'defaults',
      setting => 'fact_caching_timeout',
      value   => '86400',
    }
  }

}
