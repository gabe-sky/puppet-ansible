# This very very simple fact looks to see if this module has generated an SSH
# keypair for ansible to use.  And if it finds one, parses out just the crypto-
# graphic portion of the key, so that it's easy to use in an ssh_authorized_key
# resource on all the targets.

Facter.add('ansible_ssh_key') do
  confine :kernel => 'Linux'
  pubkey = '/etc/ansible/ssh/id_rsa.ansible.pub'

  if File.exists? pubkey
    setcode do
      File.read(pubkey).split[1]
    end
  end

end
