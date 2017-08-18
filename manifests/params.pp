# This class supplies sensible defaults for parameters used by other classes.

class ansible::params {

  case $::os['family'] {

    'RedHat': {
      case $::os['release']['major'] {
        '7': {
          $controller_pkglist = ['ansible', 'PyYAML', 'libtomcrypt',
            'libtommath', 'libyaml', 'python-babel', 'python-httplib2',
            'python-jinja2', 'python-keyczar', 'python-markupsafe',
            'python-six', 'python2-crypto', 'python2-ecdsa',
            'python2-paramiko', 'python2-pyasn1','sshpass']
        }
        '6': {
          $controller_pkglist = ['ansible', 'PyYAML', 'libyaml', 'python-babel',
            'python-crypto2.6', 'python-httplib2', 'python-jinja2-26',
            'python-keyczar', 'python-markupsafe', 'python-pyasn1',
            'python-simplejson', 'sshpass']
        }
        default: {
          fail("The ansible module cannot be safely used on RHEL ${::os['release']['major']}.")
        }
      }
    }

    'Debian': {
    }

    default: {
      fail("The ansible module cannot be safely used on ${::os['family']}.")
    }
  }

}
