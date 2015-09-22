# Installing the CartoDB mapping framework on an Ubuntu server

[Project page](https://github.com/CartoDB/cartodb)

[Documentation](https://cartodb.com/docs/)

This is mostly a copy of the official CartoDB [docs](http://cartodb.readthedocs.org/en/latest/install.html), with notes added for our environment.

Before starting the official install instructions, this list must be followed:

- Make sure Ubuntu version matches that noted on the CartoDB github page (12.04 at the time of this writing 6/2015)
- If inside corporate proxy:
  - Procure proxy client root-ca certificates
  - `cp` cert file(s) into `/usr/local/share/ca-certificates`
  - run `sudo update-ca-certificates`
  - If using GUI Ubuntu:
    - Launch Firefox, import both certs into Firefox settings
    - Download & install Chrome, then import certs into Chrome settings

Note: if behind corporate proxy, github repositories likely must be accessed via SSH instead of SSL; therefore an SSH key must be generated and imported into a github account.

For any doubt about the process you can ask in the [Google
Group](https://groups.google.com/forum/#!forum/cartodb).

---

First, install git, then download CartoDB by cloning this repository:

```bash
$ sudo apt-get install git
$ git clone --recursive git@github.com:CartoDB/cartodb.git
```

Or you can just [download the CartoDB zip
file](https://github.com/CartoDB/cartodb/archive/master.zip).


## What does CartoDB depend on? #

  - Ubuntu 12.04
  - Postgres 9.3.x (with plpythonu extension)
  - [cartodb-postgresql](https://github.com/CartoDB/cartodb-postgresql) extension
  - Redis 2.2+
  - Ruby 1.9.3
  - Node.js 0.10.x
  - CartoDB-SQL-API
  - GEOS 3.3.4
  - GDAL 1.10.x (Starting with CartoDB 2.2.0)
  - PostGIS 2.1.x
  - Mapnik 2.1.1
  - Windshaft-cartodb
  - ImageMagick 6.6.9+ (for the testsuite)


## Add CartoDB [PPA](https://help.ubuntu.com/community/PPA)s ##

First, retrieve new lists of packages:
```
sudo apt-get update
```

Install python software properties to be able to run `add-apt-repository`
```
sudo apt-get install python-software-properties
```

Add CartoDB Base PPA
```bash
sudo add-apt-repository ppa:cartodb/base
```

Add CartoDB GIS PPA
```bash
sudo add-apt-repository ppa:cartodb/gis
```

Add CartoDB Mapnik PPA
```bash
sudo add-apt-repository ppa:cartodb/mapnik
```

Add CartoDB Node PPA
```bash
sudo add-apt-repository ppa:cartodb/nodejs
```

Add CartoDB Redis PPA
```bash
sudo add-apt-repository ppa:cartodb/redis
```

Add CartoDB PostgreSQL PPA
```bash
sudo add-apt-repository  ppa:cartodb/postgresql-9.3
```
Resfresh repositories to use the PPAs
```bash
sudo apt-get update
```

## Some dependencies ##

Installations assume you use UTF8, you can set it like this:
```bash
echo -e 'LANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8' | sudo tee /etc/default/locale
source /etc/default/locale
```

[make](https://help.ubuntu.com/community/CompilingEasyHowTo) is required to compile sources
```bash
sudo apt-get install build-essential checkinstall
```

unp is required for archive file upload support

```bash
sudo apt-get install unp
```

zip is required for table exports
```bash
sudo apt-get install zip
```

## Install GEOS ##
[GEOS](http://trac.osgeo.org/geos) is required for geometry function support.

```bash
sudo apt-get install libgeos-c1 libgeos-dev
```

## Install GDAL ##
[GDAL](http://www.gdal.org) is requires for raster support.

```bash
sudo apt-get install gdal-bin libgdal1-dev
```

## Install JSON-C ##
[JSON-C](http://oss.metaparadigm.com/json-c) is required for GeoJSON support.

```bash
sudo apt-get install libjson0 python-simplejson libjson0-dev
```

## Install PROJ ##
[PROJ4](http://trac.osgeo.org/proj) is required for reprojection support.

```bash
sudo apt-get install proj-bin proj-data libproj-dev
```

## Install PostgreSQL ##
[PostgreSQL](http://www.postgresql.org) is the relational database
that powers CartoDB.

```bash
sudo apt-get install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3
```

plpython is required for Python support

```bash
sudo apt-get install postgresql-plpython-9.3
```


Currently there is an error with credential-based connections for development, and all connections must be performed using method "trust" inside config file `pg_hba.conf`.

```bash
cd /etc/postgresql/9.3/main
sudo vim pg_hba.conf
```

And change inside all local connections from peer/md5/... to trust.

Then restart postgres **twice** (seriously) and you're done.
```bash
sudo /etc/init.d/postgresql restart
```
```bash
sudo /etc/init.d/postgresql restart
```


## Install PostGIS ##
[PostGIS](http://postgis.net) is
the geospatial extension that allows PostgreSQL to support geospatial
queries. This is the heart of CartoDB!

```bash
cd /usr/local/src
sudo wget http://download.osgeo.org/postgis/source/postgis-2.1.7.tar.gz
sudo tar -xvzf postgis-2.1.7.tar.gz
cd postgis-2.1.7
sudo ./configure --with-raster --with-topology
sudo make
sudo make install
```

Finally, CartoDB depends on a geospatial database template named
`template_postgis`.

```bash
sudo su - postgres
POSTGIS_SQL_PATH=`pg_config --sharedir`/contrib/postgis-2.1
createdb -E UTF8 template_postgis
createlang -d template_postgis plpgsql
psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis'"
psql -d template_postgis -c "CREATE EXTENSION postgis"
psql -d template_postgis -c "CREATE EXTENSION postgis_topology"
psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
exit
```

## Install cartodb-postgresql ##

```bash
cd /tmp
git clone git@github.com:CartoDB/pg_schema_triggers.git
cd pg_schema_triggers
sudo make all install PGUSER=postgres
sudo make installcheck PGUSER=postgres # to run tests
cd ..
git clone git@github.com:CartoDB/cartodb-postgresql.git
cd cartodb-postgresql
git checkout cdb
sudo make all install
sudo PGUSER=postgres make installcheck # to run tests
```

**NOTE:** if test_ddl_triggers fails it's likely due to an incomplete installation of schema_triggers.
You need to add schema_triggers.so to the shared_preload_libraries setting in postgresql.conf :

```
$ sudo vim /etc/postgresql/9.3/main/postgresql.conf
...
shared_preload_libraries = 'schema_triggers.so'

$ sudo service postgresql restart # restart postgres
```

After this change the 2nd installcheck of cartodb-postresql should be OK.

Check https://github.com/cartodb/cartodb-postgresql/ for further reference

## Install Ruby ##

CartoDB is a Ruby on Rails app, so Ruby must be installed. I found [rbenv](https://github.com/sstephenson/rbenv#installation) the easiest way.

To install rbenv and Ruby:

### rbenv
From the official guide on https://github.com/sstephenson/rbenv#installation

```bash
git clone git@github.com:sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

Restart bash or open a new terminal window.

```bash
type rbenv
#=> "rbenv is a function"
```

Now, try `rbenv install -l`. If you get an error about `install` not being a command, [another small plugin](https://github.com/sstephenson/ruby-build#readme) needs to be installed:

```bash
git clone git@github.com:sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
```

Then, install & set Ruby:

```bash
rbenv install 1.9.3-p551 # this takes a while...
rbenv global 1.9.3-p551
```

Then, to install bundler simply run:

```bash
gem install bundler
```

## Install Node.js ##
The tiler API and the SQL API are both [Node.js](http://nodejs.org) apps.

```bash
sudo add-apt-repository ppa:cartodb/nodejs-010
sudo apt-get update
sudo apt-get install nodejs
```

We currently run our node apps against version 0.10. You can install [NVM](https://github.com/creationix/nvm)
to handle multiple versions in the same system:

```bash
# this tales a while
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.25.4/install.sh | bash
```

(I know, [curl-pipe-bash](http://curlpipesh.tumblr.com/)... [here's the script](https://github.com/creationix/nvm/blob/v0.25.4/install.sh) for safety's sake.)

Then you can install and use any version, for example:
```bash
nvm install v0.10
nvm use 0.10
```


## Install Redis ##
Components of CartoDB, like Windshaft or the SQL API depend on [Redis](http://redis.io).

```bash
sudo apt-get install redis-server
```

Redis needs to be made persistent; see [here](http://redis.io/topics/persistence) for details. First, make the config file:

```bash
cd wherever/cartodb
nano redis.conf
```

Then, add this line to configure RDB persistence:
```bash
save 60 1000
```

This configuration seems to work in development, however if any issues arise with Redis it may need to be tweaked.

## Install Python dependencies ##
This needs to be done from the cartodb local copy.
To install the Python modules that CartoDB depends on, you can use
`easy_install`.

You need to have some dependencies installed before using pip:
```bash
sudo apt-get install python2.7-dev
sudo apt-get install build-essential
sudo su
apt-get install python-setuptools
```

Note, pip seems to be cranky about SSL, so we have to point it directly to our Zscaler cert (if one fails, try the other). Also, I was unable to overcome ssl/cert issues with `easy_install`, so I downloaded a local copy of the installer, unpacked it, altered the `get-pip.py` installer to point to the original unpacked package, and ran in that way.

```bash
# download local copies of the pip package
# and the pip installer
# edit installer to call local file
# then run unstaller

export CPLUS_INCLUDE_PATH=/usr/include/gdal
export C_INCLUDE_PATH=/usr/include/gdal
pip install --no-use-wheel --cert /path/to/Zscaler/cert -r python_requirements.txt
exit
```

If the previous step fails, try this alternative:
```bash
export CPLUS_INCLUDE_PATH=/usr/include/gdal
export C_INCLUDE_PATH=/usr/include/gdal
sudo pip install --no-install GDAL
cd /tmp/pip_build_root/GDAL
sudo python setup.py build_ext --include-dirs=/usr/include/gdal
sudo pip install --no-download GDAL
```

## Install Mapnik ##
[Mapnik](http://mapnik.org) is an API for creating beautiful maps.
CartoDB uses Mapnik for creating and styling map tiles.

```bash
sudo apt-get install libmapnik-dev python-mapnik mapnik-utils
```

## Install CartoDB SQL API ##
The [CartoDB SQL API](https://github.com/CartoDB/CartoDB-SQL-API)
component powers the SQL queries over HTTP. To install it:

```bash
cd ~
git clone git@github.com:CartoDB/CartoDB-SQL-API.git
cd CartoDB-SQL-API
git checkout master

# this is insecure, but I couldn't find
# another way around cert issues without it
npm config set strict-ssl false
npm install
cp config/environments/development.js.example config/environments/development.js
```

To run CartoDB SQL API in development mode, simply type:

```bash
node app.js development
```

## Install Windshaft-cartodb ##
The [Windshaft-cartodb](https://github.com/CartoDB/Windshaft-cartodb)
component powers the CartoDB Maps API.

Apparently, Pango is required for Windshaft's installation ([source](https://github.com/CartoDB/cartodb/issues/2550)), but hasn't been installed up to this point:

```bash
sudo apt-get install libpango1.0-dev
```

Then, to install Windshaft:

```bash
cd ~
git clone git://github.com/CartoDB/Windshaft-cartodb.git
cd Windshaft-cartodb
git checkout master
npm install
cp config/environments/development.js.example config/environments/development.js
```
To run Windshaft-cartodb in development mode, simply type:

```bash
node app.js development
```

## Install ImageMagick ##

```bash
sudo apt-get install imagemagick
```

## Activate Sync Tables ##

For some reason, the default install is configured as a free-tier account, which is missing features like [sync tables](http://docs.cartodb.com/tutorials/realtime_maps_sync.html).

You can enable them in the interface for all the users in your local install by updating the `sync_tables_enabled` row on the `users` table:

```bash
sudo su
su postgres
psql carto_db_development

# If this gives an error about
# postgresql boolean types,
# change 1 to 'true':
UPDATE users SET sync_tables_enabled = 1;

\q
exit
exit
```

However, sync tables also require a script to run every 15 minutes, which will enqueue pending synchronizations (run this in the `cartodb/` directory):

```bash
RAILS_ENV=development bundle exec rake cartodb:sync_tables
```

This command will need to be scheduled to run at a regular interval, i.e. every 15 minutes or so. Also, the environment should be changed in the command as necessary. Add to crontab like so:

```bash
*/15 * * * *    username  cd /wherever/cartodb && RAILS_ENV=development bundle exec rake cartodb:sync_tables
```

## Optional components
The following are not strictly required to run CartoDB:

### Varnish

[Varnish](https://www.varnish-cache.org) is a web application
accelerator. Components like Windshaft use it to speed up serving tiles
via the Maps API.

Add CartoDB Varnish PPA and install it:
```bash
sudo add-apt-repository  ppa:cartodb/varnish
sudo apt-get update
sudo apt-get install varnish=2.1.5.1-cdb1 #or any version <3.x
```

Varnish should allow telnet access in order to work with CartoDB, so you need to edit the `/etc/default/varnish` file and in the `DAEMON_OPTS` variable remove the `-S /etc/varnish/secret \` line.

### Raster import support
Raster importer needs `raster2pgsql` to be in your path. You can check whether it's available by running `which raster2pgsql`. If it's not, you should link it: `$ sudo ln -s /usr/local/src/postgis-2.1.7/raster/loader/raster2pgsql /usr/bin/`.

Access to temporary dir is also needed. Depending on your installation you might also need to run `sudo chown 501:staff /usr/local/src/postgis-2.1.7/raster/loader/.libs` (maybe replacing `501:staff` with your installation /usr/local/src/postgis-2.1.7/raster/loader/ group and owner).

## Install problems and common solutions #

Installing the full stack might not always be smooth due to other component updates, so if you run into problems installing CartoDB, please check [this list of problems and solutions](https://github.com/CartoDB/cartodb/wiki/Problems-faced-during-CartoDB-install-&-solutions-if-known) first to see if your problem already happened in the past and somebody else found a workaround, solution or fix to it.

# Running CartoDB #

## First run ##

Time to run your development version of CartoDB. Let's suppose that
we are going to create a development env and that our user/subdomain
is going to be 'development'

```bash
export SUBDOMAIN=development

# Enter the `cartodb` directory.
cd cartodb

# Start redis, if you haven't done so yet
# Redis must be running when starting either the
# node apps or rails or running the ``create_dev_user script``
# NOTE: the default server port is 6379, and the default
#       configuration expects redis to be listening there
redis-server

# Run this to sync user config
# from postgres metadata to redis metadata
# per: https://groups.google.com/d/msg/cartodb/-9QB9D4ZfSc/_tngHpl48U0J
# Configuring redis persistence should ensure
# that this won't need to be re-run
./script/restore_redis

# Same with CartoDB-SQL-API
cd wherever/CartoDB-SQL-API/
node app.js development

# Then, move back into cartodb directory
cd wherever/cartodb/

# First, due to our proxy https issues,
# I changed all refs to github pages
# in the Gemfile (`cartodb/Gemfile`)
# from `https` notation to `ssh` notation.

# If it's a system wide installation
bundle install

# If you are using rbenv simply run:
rbenv local 1.9.3-p551
bundle install

# Configure the application constants
cp config/app_config.yml.sample config/app_config.yml
vim config/app_config.yml

# Configure your postgres database connection details
cp config/database.yml.sample config/database.yml
vim config/database.yml

# Add entries to /etc/hosts needed in development
echo "127.0.0.1 ${SUBDOMAIN}.localhost.lan" | sudo tee -a /etc/hosts

# Create a development user
#
# The script will ask you for passwords and email
#
# Read the script for more informations about how to perform
# individual steps of user creation and settings management
#
sh script/create_dev_user ${SUBDOMAIN}
```

Start the resque daemon (needed for import jobs):

```bash
$ bundle exec script/resque
```

Finally, start the CartoDB development server on port 3000:

```bash
$ bundle exec rails s -p 3000
```

You should now be able to access
**`http://<mysubdomain>.localhost.lan:3000`**
in your browser and login with the password specified above.

---

## Firing everything up after first run ##

```bash
cd wherever/CartoDB-SQL-API
node app.js development

cd wherever/Windshaft-cartodb
node app.js development

cd wherever/cartodb

redis-server

bundle exec script/resque

bundle exec rails s -p 3000
```

---

## Running the stack persistently ##

Once everything is installed & configured, all 5 services need to be configured to run automatically on system boot in the background. This should eventually be accomplished with an init script for each of the 5 services; however I have thrown together this simple workaround until I get to writing the inits.

Make a bash script that starts each service:

cdb-sql-api.sh

```bash
#!/bin/bash

cd /wherever/CartoDB-SQL-API
node app.js development
```

cdb-windshaft.sh

```bash
#!/bin/bash

cd /wherever/Windshaft-cartodb
node app.js development
```

cdb-redis-server.sh

```bash
#!/bin/bash

cd /wherever/cartodb
redis-server
```

cdb-resque.sh

```bash
#!/bin/bash

cd /wherever/cartodb
bundle exec script/resque
```

cdb-cdb.sh

```bash
#!/bin/bash

cd /wherever/cartodb
bundle exec rails s -p 3000
```

And now we add them as reboot items in the `crontab`, forwarding the STDOUT of each process to its own log for debugging:

```bash
@reboot  username  bash /wherever/cdb-sql-api.sh > /wherever/devlog.txt 2>&1 &
@reboot  username  bash /wherever/cdb-windshaft.sh > /wherever/devlog.txt 2>&1 &
@reboot  username  bash /wherever/cdb-redis-server.sh > /wherever/devlog.txt 2>&1 &
@reboot  username  bash /wherever/cdb-resque.sh > /wherever/devlog.txt 2>&1 &
@reboot  username  bash /wherever/cdb-cdb.sh > /wherever/devlog.txt 2>&1 &
```

Boom.

---

## Note on tiling, SQL API and Redis

Please ensure CartoDB-SQL-API, Windshaft-cartodb, and Redis are all
running for full experience.

Manual configuration is needed for the
`public/javascripts/environments/development.js` file which configures
Windshaft-cartodb tile server URLs.

## Handy tasks

For a full list of CartoDB utility tasks:

```
bundle exec rake -T
```

## Using foreman

You can also use foreman to run the full stack (cartodb server, sql api, tiler, redis and resque), using a single command:
IMPORTANT: You need to install foreman by yourself. It's not included in the Gemfile. Run this:

```
bundle exec gem install foreman
```

```
bundle exec foreman start -p $PORT
```

where $PORT is the port you want to attach the rails server to.


# How do I upgrade CartoDB? #

See [UPGRADE](https://github.com/CartoDB/cartodb/blob/master/UPGRADE) for instructions about upgrading CartoDB.

For upgrade of Windshaft-CartoDB and CartoDB-SQL-API see the relative
documentation.
