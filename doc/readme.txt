             -= MeritCommons Portal =-
        (c) 2017 Wayne State University
                Detroit, MI 48202
              Version 0.99 - Cass

--[ Installation Instructions ]
  
  Using MeritCommons System (Currently requires LSB-Compliant Linux amd64):

  0). MeritCommons Sys requires libgomp, and some LaTeX libs for x86_64.

  You can install on CentOS 6 with:

  yum install texlive-latex libgomp

  On Debian or Ubuntu please use:

  apt-get install libgomp1 libaio-dev texlive-science texlive-math-extra texlive-music texlive-latex texlive-latex3 texlive-latex-base texlive dvipng

  1). Create a user to run MeritCommons Portal as, preferably with the home directory 
  /usr/local/meritcommons.

  sudo useradd -d /usr/local/meritcommons -s /bin/bash -c "MeritCommons User" -m meritcommons

  2). Copy in your tarballs, make sure they're owned by your meritcommons user.

  sudo cp meritcommons-0.43.tar.gz meritcommons_sys-1.4.tar.gz /usr/local/meritcommons
  sudo chown meritcommons:meritcommons /usr/local/meritcommons/*.tar.gz

  3). Become the meritcommons user.

  sudo su - meritcommons

  4). Untar MeritCommons and MeritCommons System

  tar -xvzf meritcommons_0.43.tar.gz
  tar -xvzf meritcommons_sys-1.4.tar.gz

  5). Create "meritcommons" and "sys" symlinks

  ln -s meritcommons_0.43 meritcommons
  ln -s meritcommons_sys-1.4 sys

  6). Setup MeritCommons Environment

  echo ". /usr/local/meritcommons/sys/.sysbashrc" >> ~/.bashrc
  . /usr/local/meritcommons/sys/.sysbashrc

  7). Create directories
  
  mkdir -p /usr/local/meritcommons/var/pgsql/data
  mkdir -p /usr/local/meritcommons/var/sphinx/data
  mkdir -p /usr/local/meritcommons/var/log
  mkdir -p /usr/local/meritcommons/var/state
  mkdir -p /usr/local/meritcommons/var/public
  mkdir -p /usr/local/meritcommons/var/plugins
  mkdir -p /usr/local/meritcommons/var/bloomd
  mkdir -p /usr/local/meritcommons/var/plugins
  mkdir -p /usr/local/meritcommons/var/dumps
  mkdir -p /usr/local/meritcommons/var/s3

  8). Setup PostgreSQL

  # init db environment
  /usr/local/meritcommons/sys/pgsql/bin/initdb

  # start postgres
  /usr/local/meritcommons/sys/pgsql/bin/pg_ctl -D /usr/local/meritcommons/var/pgsql/data -l logfile start

  # create meritcommons database
  psql -d template1 -c "create database meritcommons;"
  psql -d template1 -c "create database meritcommons_async;"

  9). Setup SphinxDB
  
  # configure sphinx
  cp /usr/local/meritcommons/meritcommons/etc/sphinx.conf.sample /usr/local/meritcommons/meritcommons/etc/sphinx.conf

  # start sphinx / searchd
  searchd -c /usr/local/meritcommons/meritcommons/etc/sphinx.conf

  10). Configure MeritCommons

  cp /usr/local/meritcommons/meritcommons/etc/meritcommons.conf.sample /usr/local/meritcommons/meritcommons/etc/meritcommons.conf
  
  vi /usr/local/meritcommons/meritcommons/etc/meritcommons.conf 
   * Change authentication_provider to MeritCommons::Helper::LocalAuth (or configure LDAP) 
   * Change cookie_domain to the hostname of the machine hosting meritcommons
   * Change cookie_top_domain to the domain name for campus wide SSO e.g. '.wayne.edu'
   * Change advertised_websocket to reflect the proper websocket address e.g. 'ws://meritcommons-dev.wayne.edu:3000/hydrant'
   * Configure Database dsn (for Postgres, set to: 'dbi:Pg:host=localhost;dbname=meritcommons')
   * Uncomment pg_enable_utf8 => 1, and database user and password fields

  11). Install Schema

  meritcommons install_schema

  12). Create a new user (if LDAP isn't configured)

  meritcommons new_local_user mikey "Mikey G" abc123

  13). Configure your OS' firewall

   * If you're running with devdaemon, open up port 3000, else 80 and 443
    
    iptables -I INPUT 3 -m state --state new -m tcp -p tcp --dport 3000 -j ACCEPT

   * If running in production, I find it's easier to not deal with setuid/setgid and binding 
     to privileged ports.  You can configure your instance to bind to 8080 and 8443 and do a 
     local port forward like this

    # set up the forward
    iptables -t nat -A PREROUTING -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 8080
    iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 8443

    # make sure you open those ports, too
    iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
    iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 8443 -j ACCEPT
    iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
    iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT

-- [TL;DR installer copypasta]

  sudo useradd -d /usr/local/meritcommons -s /bin/bash -c "MeritCommons User" -m meritcommons
  sudo cp meritcommons-0.43.tar.gz meritcommons_sys-1.4.tar.gz /usr/local/meritcommons
  sudo chown meritcommons:meritcommons /usr/local/meritcommons/*.tar.gz
  sudo su - meritcommons
  tar -xvzf meritcommons-0.43.tar.gz
  tar -xvzf meritcommons_sys-1.4.tar.gz
  ln -s meritcommons_0.43 meritcommons
  ln -s meritcommons_sys-1.4 sys
  echo ". /usr/local/meritcommons/sys/.sysbashrc" >> /usr/local/meritcommons/.bashrc
  . /usr/local/meritcommons/sys/.sysbashrc
  mkdir -p /usr/local/meritcommons/var/pgsql/data
  mkdir -p /usr/local/meritcommons/var/sphinx/data
  mkdir -p /usr/local/meritcommons/var/log
  /usr/local/meritcommons/sys/pgsql/bin/initdb
  psql -d template1 -c "create database meritcommons;"
  ./sys/pgsql/bin/pg_ctl -D /usr/local/meritcommons/var/pgsql/data -l logfile start
  cp /usr/local/meritcommons/meritcommons/etc/sphinx.conf.dist /usr/local/meritcommons/meritcommons/etc/sphinx.conf
  searchd -c /usr/local/meritcommons/meritcommons/etc/sphinx.conf
  cp /usr/local/meritcommons/meritcommons/etc/meritcommons.conf.sample /usr/local/meritcommons/meritcommons/etc/meritcommons.conf
  vi /usr/local/meritcommons/meritcommons/etc/meritcommons.conf
  meritcommons install_schema force_overwrite
