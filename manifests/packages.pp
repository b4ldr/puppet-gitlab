# init -> packages -> user -> setup -> install -> config -> service
class gitlab::packages inherits gitlab {
  
  include apt
    

  $system_packages = [
                    'libicu-dev',
                    'python2.7',
                    'python-docutils',
                    'libxml2-dev',
                    'libxslt1-dev',
                    'python-dev',
                    'build-essential',
                    'libmysqlclient-dev',
                    'redis-server',
                    'logrotate',
                      ]
  ensure_packages($system_packages)

  ## Git v1.7.10
  # =====================================


  # Include git ppa (gitlab requires git 1.7.10 or newer which isn't in standard repo)
  apt::ppa { 'ppa:git-core/ppa':
  }

  # Install key for repo (otherwise it prints error)
  apt::key { 'ppa:git-core/ppa':
      key   =>  'E1DF1F24',
  }

  package { 'git-core':
    ensure  =>  latest,
    require =>  [
        Apt::Ppa['ppa:git-core/ppa'],
        Apt::Key['ppa:git-core/ppa'],
                ],
  }


  ## Ruby
  # =====================================

  class { 'ruby':
    ruby_package      =>  'ruby1.9.1-full',
    rubygems_package  =>  'rubygems1.9.1',
    rubygems_update   =>  true,
    gems_version      =>  'latest',
  }

  exec {'update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 10':
    path    =>  '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    command =>  'update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 10',
    unless  => 'update-alternatives --query ruby | grep -w /usr/bin/ruby1.9.1',
  }

  exec {'update-alternatives --set ruby /usr/bin/ruby1.9.1':
    path    =>  '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    command =>  'update-alternatives --set ruby /usr/bin/ruby1.9.1',
    unless  => 'update-alternatives --get-selections | grep -w /usr/bin/ruby1.9.1',
    require =>  Exec['update-alternatives --install /usr/bin/ruby ruby /usr/bin/ruby1.9.1 10'],
  }

  exec {'update-alternatives --install /usr/bin/gem gem /usr/bin/gem1.9.1 10':
    path    =>  '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    command =>  'update-alternatives --install /usr/bin/gem gem /usr/bin/gem1.9.1 10',
    unless  => 'update-alternatives --query gem | grep -w /usr/bin/gem1.9.1',
  }

  exec {'update-alternatives --set gem /usr/bin/gem1.9.1':
    path    =>  '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin',
    command =>  'update-alternatives --set gem /usr/bin/gem1.9.1',
    unless  => 'update-alternatives --get-selections | grep -w /usr/bin/gem1.9.1',
    require =>  Exec['update-alternatives --install /usr/bin/gem gem /usr/bin/gem1.9.1 10'],
  }



  ## MySQL
  # =====================================

  # The end user must manually setup the database
  # see tests/init.pp for an example
  mysql::db { "${gitlab::gitlab_dbname}" :
    ensure    =>  present,
    user      =>  "${gitlab::gitlab_dbuser}",
    password  =>  "${gitlab::gitlab_dbpwd}",
    host      =>  "${gitlab::gitlab_dbhost}",
    grant     =>  ['SELECT', 'LOCK TABLES', 'INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'INDEX', 'ALTER'],
  }


  ## Postfix
  # ===================================
  include postfix

  ## Nginx
  # ===================================
  include nginx
  nginx::resource::upstream { 'gitlab':
    ensure  => present,
    members => [
      "unix:${gitlab::git_home}/gitlab/tmp/sockets/gitlab.socket"
    ]
  }
  if $gitlab::gitlab_ssl {
    $nginx_listen_port = 443
    $nginx_add_header = {
      strict_transport_security => 'max-age=31536000; includeSubDomains'
    }
    $nginx_proxy_header = [
      'Host $http_host',
      'X-Real-IP $remote_addr',
      'X-Forwarded-For $proxy_add_x_forwarded_for',
      'X-Forwarded-Proto $scheme',
      'X-Forwarded-Ssl   on',
    ]
    nginx::resource::vhost { "${::fqdn}-redirect":
      ensure           => present,
      server_name      => [$::fqdn],
      rewrite_to_https => true,
      www_root         => "${gitlab::git_home}/gitlab/public",
    }
  } else {
    $nginx_listen_port = 80
    $nginx_add_header = undef
    $nginx_proxy_header = [
      'Host $http_host',
      'X-Real-IP $remote_addr',
      'X-Forwarded-For $proxy_add_x_forwarded_for',
      'X-Forwarded-Proto $scheme',
    ]
  }
  nginx::resource::vhost { $::fqdn:
    ensure      => present,
    listen_port => $nginx_listen_port,
    www_root    => "${gitlab::git_home}/gitlab/public",
    ssl         => $gitlab::gitlab_ssl,
    ssl_cert    => $gitlab::gitlab_ssl_cert,
    ssl_key     => $gitlab::gitlab_ssl_key,
    add_header  => $nginx_add_header,
    try_files   => ['$uri', '$uri/index.html', '$uri.html', '@gitlab']
  }
  nginx::resource::location { '@gitlab':
    location              => '@gitlab',
    proxy                 => 'http://gitlab',
    vhost                 => $::fqdn,
    ssl                   => $gitlab::gitlab_ssl,
    ssl_only              => $gitlab::gitlab_ssl,
    proxy_read_timeout    => 300,
    proxy_connect_timeout => 300,
    proxy_set_header      => $nginx_proxy_header,
  }

}# end packages.pp
