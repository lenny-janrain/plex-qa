#!/bin/bash
#grab the platform config from vagrant if one was specified
if [ -n $1 ]; then
  PLEXREPO=$1
fi

#initialize package manager
apt-get -qq update && apt-get -qq dist-upgrade

#install apt-get predependencies
apt-get -qqy install dkms fuse lsb-base ubuntu-standard ubuntu-minimal

#install mysql (Percona)
apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
echo 'deb http://repo.percona.com/apt trusty main' > /etc/apt/sources.list.d/percona.list
apt-get -qq update
debconf-set-selections <<< 'percona-server-server-5.5 percona-server-server/root_password password g0janrain'
debconf-set-selections <<< 'percona-server-server-5.5 percona-server-server/root_password_again password g0janrain'
apt-get -qqy install percona-server-server-5.5
mysql -pg0janrain -e "GRANT ALL ON *.* TO 'vagrant'@'localhost';"

#install packages
export DEBIAN_FRONTEND=noninteractive
apt-get -qqy install php5-cli php5-mysqlnd apache2 libapache2-mod-php5 php5-mcrypt php5-curl php5-gd curl git python3 php-pear

#install composer globally
if ! type composer >/dev/null 2>&1; then
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  FILE="/etc/bash.bashrc"
  if [[ 0 == $(grep -c ".composer/vendor/bin" $FILE) ]]; then
    sed -i '1i export PATH="$HOME/.composer/vendor/bin:$PATH"' $FILE
  fi
fi
export PATH=$HOME/.composer/vendor/bin:$PATH

echo 'install drush'
composer global require drush/drush --no-progress
su - vagrant -c "composer global require drush/drush --no-progress"

echo
echo 'Configuring Apache...'
cp -f /vagrant/plex-tools/vagrant/php.ini /etc/php5/apache2/php.ini

#enable rewrites
a2enmod rewrite >/dev/null

# Update apache config
FILE="/etc/apache2/apache2.conf"
if [[ 0 == $(grep -c "ServerName " $FILE) ]]; then
  # no ServerName declaration add it
  echo 'ServerName vcap.me' >> /etc/apache2/apache2.conf
fi
sed -i '166s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
sed -i 's/DocumentRoot \/var\/www\/html/DocumentRoot \/var\/www/g' /etc/apache2/sites-available/000-default.conf
sed -i 's/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=vagrant/g' /etc/apache2/envvars
sed -i 's/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=vagrant/g' /etc/apache2/envvars

#remove defaultf apache index
if [[ -d "/var/www/html" ]]; then
  rm -rf /var/www/html
fi

#add phpinfo index if there's not one there
if [[ ! -f "/var/www/index.php" ]]; then
  echo "<?php phpinfo();" > /var/www/index.php
fi

#make apache user own webroot
chown -fR vagrant.vagrant /var/www
chown vagrant /var/lock/apache2

#make webroot keep permissions
chmod ug+rws /var/www

#make changes take effect
service apache2 restart

#move into web root to prepare for custom platform script
cd /var/www

#provision a custom environment if specified
if [ -f "/vagrant/plex-tools/vagrant/$PLEXREPO.sh" ]; then
  echo "Provisioning environment for ${PLEXREPO}..."
  #configure platform, calls the respective platform provisioner provided in the environment settings
  source /vagrant/plex-tools/vagrant/${PLEXREPO}.sh
elif [ -z "$PLEXREPO" ]; then
  echo "No repo specified, bare LAMP server provisioned."
else
  echo "Invalid repo specified, bare LAMP server provisioned."
fi
cd /var/www
echo 'Checking for Drupal...'
if [[ ! -d "/var/www/includes" ]];then
  echo '  Drupal not detected, installing drupal with drush...'
  drush dl --drupal-project-rename="drupal"
  mv drupal/* drupal/.* ./ && rmdir drupal
  drush si -y --account-pass=g0janrain --db-url=mysql://root:g0janrain@localhost/drupal


else echo -e ' \xe2\x9c\x93 Drupal already installed.';
fi

echo 'Installing google_analytics module'
drush en -y analytics
echo 'Installing libraries module'
drush en -y libraries
echo 'Installing rules module'
drush en -y rules
echo 'Installing token module'
drush en -y token
echo 'Installing captcha module'
drush en -y captcha
echo 'Installing date module'
drush en -y date
echo 'Installing eck module'
drush en -y eck
echo 'Installing features module'
drush en -y features
echo 'Installing views module'
drush en -y views
echo 'Installing rules module'
drush en -y rules
echo 'Installing services module'
drush en -y services
echo 'Installing janrain_capture module'
drush en -y janrain_capture janrain_capture_screens janrain_capture_ui janrain_capture_mapping
echo 'generating data'
drush en -y devel
drush en -y devel_generate

cd /var/www
drush cc all
drush genc 500 5
drush genm
drush genu 50

#use this code only for enabling and deploying the janrain v2 module
drush en -y janrain

#make sure apache/drupal own the web tree
chown -R vagrant.vagrant /var/www

echo "Provisioning complete! CMD-double-click http://vcap.me/ to view your site!"
