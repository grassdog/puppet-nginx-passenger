# Class: nginx
#
# This module installs Nginx and its default configuration using rbenv.
#
# Parameters:
#   $ruby_version
#       Ruby version to install.
#   $passenger_version
#      Passenger version to install.
#   $logdir
#      Nginx's log directory.
#   $installdir
#      Nginx's install directory.
#   $www
#      Base directory for
# Actions:
#
# Requires:
#    puppet-rbenv
#
# Sample Usage:  include nginx
class nginxpassenger (
  $ruby_version = '1.9.3-p327',
  $user = 'www-data',
  $passenger_version = '3.0.19',
  $logdir = '/var/log/nginx',
  $installdir = '/opt/nginx',
  $www    = '/var/www' ) {

    $options = "--auto --auto-download  --prefix=${installdir}"
    $passenger_deps = [ 'libcurl4-openssl-dev' ]
    

    package { 'passenger_deps':
      name => $passenger_deps,
      ensure => present
    }

    rbenv::install { $user:
      user => $user,
      home => "/home/${user}",
      require => User[$user]
    }

    rbenv::compile { "${user}/${ruby_version}":
      user => $user,
      home => "/home/${user}",
      ruby => $ruby_version,
      global => true
    }

    rbenv::gem { "${user} ${ruby_version} passenger":
      gem => 'passenger',
      user => $user,
      ruby => $ruby_version
    } -> Exec["rbenv::rehash ${user} ${ruby_version}"]

    exec { 'create container':
      command => "/bin/mkdir ${www} && /bin/chown www-data:www-data ${www}",
      unless  => "/usr/bin/test -d ${www}",
      before  => Exec['nginx-install']
    }

    exec { 'nginx-install':
      command => "/bin/bash -l -i -c \"/home/${user}/.rbenv/versions/${ruby_version}/bin/passenger-install-nginx-module ${options}\"",
      group   => 'root',
      unless  => "/usr/bin/test -d ${installdir}",
      require => [ Package['passenger_deps'], Rbenv::Install[$user],
                   Rbenv::Compile["${user}/${ruby_version}"], Rbenv::Gem["${user} ${ruby_version} passenger"]];
    }

    file { 'nginx-config':
      path    => "${installdir}/conf/nginx.conf",
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('nginxpassenger/nginx.conf.erb'),
      require => Exec['nginx-install'],
    }

    exec { 'create sites-conf':
      path    => ['/usr/bin','/bin'],
      unless  => "/usr/bin/test -d  ${installdir}/conf/sites-available && /usr/bin/test -d ${installdir}/conf/sites-enabled",
      command => "/bin/mkdir  ${installdir}/conf/sites-available && /bin/mkdir ${installdir}/conf/sites-enabled",
      require => Exec['nginx-install'],
    }

    file { 'nginx-service':
      path      => '/etc/init.d/nginx',
      owner     => 'root',
      group     => 'root',
      mode      => '0755',
      content   => template('nginxpassenger/nginx.init.erb'),
      require   => File['nginx-config'],
      subscribe => File['nginx-config'],
    }

    file { $logdir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0644'
    }

    service { 'nginx':
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      subscribe  => File['nginx-config'],
      require    => [ File[$logdir], File['nginx-service']],
    }

}
