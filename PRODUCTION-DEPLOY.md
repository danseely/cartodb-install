# Changing the configuration of a CartoDB development environment for full production deployment

This was *tough*, and largely undocumented. The biggest sources of insight were [this Github gist](https://gist.github.com/arjendk/6080388), the [Passenger docs](https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/Apache/oss/precise/install_passenger.html), and help from the dev team on their [Google group](https://groups.google.com/forum/#!forum/cartodb).

[Here is an official doc set that has a bit more info about installation configuration.](http://cartodb.readthedocs.org/en/latest/intro.html)

---

## Passenger

[Passenger](www.phusionpassenger.com) is a connector between a Rails application and a web server (usually Apache or Nginx).

---

## Config

CartoDB doesn't provide much documentation about deploying to a production environment, and there are very few people that have written up detailed steps to do so. It seems that most individuals/teams that are willing to tackle a production deployment are already knowledgeable about the workings of Rails & node.js applications.

It seems to come down to using different Rails environments, then running rake tasks & starting services in the context of those environments. For example, when first setting up a development copy of CartoDB, it created a development database, and when CartoDB is being served by Passenger & Apache it looks for a production DB.


When CartoDB initially wouldn't load, I looked into the Apache logs, and I saw an error about the production database not existing. So, I ran:

```bash
RAILS_ENV=production bundle exec rake db:create
```

([via](http://stackoverflow.com/questions/3690121/rails-3-creating-a-production-database))

And, that gave me a CartoDB error page -- huge progress!

After restarting Apache and reloading the site, still no-go. I checked the CartoDB log (`wherever/cartodb/logs/production.log`), and it seemed to have found the new DB but was missing tables. So I ran:

```bash
RAILS_ENV=production bundle exec rake db:migrate
```

More progress: it now redirected to the login page, but then automatically redirected to https, which isn't setup yet.

---

It seems that CartoDB is automatically redirecting the login page to https, and I didn't have SSL set up yet. I tried the suggestions from [arjendk's walkthrough](https://gist.github.com/arjendk/6080388), which looks like this:

> Create /etc/Apache2/sites-available/default-ssl with something like:

```bash
<VirtualHost *:443>
    ServerName carto.qmaps.nl
    ServerAlias carto.qmaps.nl
    # !!! Be sure to point DocumentRoot to 'public'!
    DocumentRoot /home/quser/cartodb20/public
    RailsEnv production
    PassengerSpawnMethod direct

    #TODO later: SSL options

    <Directory /home/quser/cartodb20/public>
        # This relaxes Apache security settings.
        AllowOverride all
        # MultiViews must be turned off.
        Options -MultiViews
    </Directory>
</VirtualHost>
```

However, that file already existed with a lot of default config stuff, so I added the suggested block at the top. Still errors out on page load, no change (it's `ERR-CONNECTION_REFUSED` in Chrome).

I copied the original file out to `default-ssl.default`, then created a new empty `default-ssl` and added the above block. Still no change.

Then, I followed the next 3 steps: enabling the SSL module & the SSL site:

```bash
sudo a2enmod ssl
sudo a2ensite default-ssl
```

And then, in `/etc/Apache2/ports.conf`, add NameVirtualHost 443:

```bash
<IfModule mod_ssl.c>
    NameVirtualHost *:443
    Listen 443
</IfModule>
```

According to the terminal output when enabling the above modules, I ran:

```bash
sudo service Apache2 reload
sudo Apache2ctl restart
```

And... Apache2ctl throws an error on restart. Now I'm stuck.

---

It turns our that Apache wasn't seeing the SSL config in `sites-available`. Long story short, I just added the SSL block to the main Apache/CartoDB config file at `/etc/Apache2/sites-enabled/cartodb.conf`:

```bash
<VirtualHost *:80>
    ServerName <our-ip>

    # Tell Apache and Passenger where your app's 'public' directory is
    DocumentRoot /wherever/cartodb/public

    PassengerRuby /wherever/.rbenv/versions/1.9.3-p551/bin/ruby

    # Relax Apache security settings
    <Directory /wherever/cartodb/public>
      Allow from all
      Options -MultiViews
      # Uncomment this if you're on Apache >= 2.4:
      #Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName <our-ip>
    ServerAlias <our-ip>
    # !!! Be sure to point DocumentRoot to 'public'!
    DocumentRoot /wherever/cartodb/public
    RailsEnv production
    PassengerSpawnMethod direct

    PassengerRuby /wherever/.rbenv/versions/1.9.3-p551/bin/ruby

    SSLEngine on

    SSLCertificateFile /etc/Apache2/certs/OurCert.crt
    SSLCertificateKeyFile /etc/Apache2/certs/OurKey.key

    <Directory /wherever/cartodb/public>
        # This relaxes Apache security settings.
        AllowOverride none
        Allow from all
        # MultiViews must be turned off.
        Options -MultiViews
    </Directory>
</VirtualHost>

```

Note, I also copied our self-signed certs from another server to a new directory `/etc/Apache2/certs`. And that worked, CartoDB now serves via the server IP, and automatically redirects to HTTPS.

---

Next, I need to fix imports. I cracked open `CartoDB-SQL-API/config/environments/production.js` and `Windhsaft/config/environments/production.js` (needed to create them both from their respective `.example` versions) and changed the `users_from_hosts` settings to `^(.*)\\.<our-ip>.$`. I'm not sure if this is correct, but it comes loaded with a setting for the cartodb.com url, so clearly that's not correct. I think I may need to add the regex to the end of the url after the IP, since we're using subdomainless and the user names are after the domain, instead of before it.

I then noticed in my homemade bash script logs that Windshaft (and, I assume, the SQL-API) were being run in development mode. So, I altered both startup scripts from

```bash
node app.js development
```

to

```bash
node app.js production
```

Trying that now.

---

That didn't fix the issues. I also noticed that the resque log didn't show any chatter when I attempted an import, so I added the production environment to it's bash script as well.

```bash
RAILS_ENV=production bundle exec script/resque
```

Didn't solve imports, but now I'm getting output. From the resque output:

```
** [15:44:29 2015-08-20] 2659: Sleeping for 5.0 seconds
** [15:44:29 2015-08-20] 2659: resque-1.25.2: Waiting for *
** [15:44:34 2015-08-20] 2659: Checking imports
** [15:44:34 2015-08-20] 2659: Checking users
** [15:44:34 2015-08-20] 2659: Found job on users
** [15:44:34 2015-08-20] 2659: got: (Job{users} | Resque::UserJobs::CommonData::LoadCommonData | ["9abefa46-c530-486c-9749-beca979852f9"])
** [15:44:34 2015-08-20] 2659: resque-1.25.2: Processing users since 1440099874 [Resque::UserJobs::CommonData::LoadCommonData]
** [15:44:34 2015-08-20] 2659: Running before_fork hooks with [(Job{users} | Resque::UserJobs::CommonData::LoadCommonData | ["9abefa46-c530-486c-9749-beca979852f9"])]
** [15:44:34 2015-08-20] 2659: resque-1.25.2: Forked 3779 at 1440099874
** [15:44:34 2015-08-20] 3779: Running after_fork hooks with [(Job{users} | Resque::UserJobs::CommonData::LoadCommonData | ["9abefa46-c530-486c-9749-beca979852f9"])]
** [15:44:39 2015-08-20] 3779: done: (Job{users} | Resque::UserJobs::CommonData::LoadCommonData | ["9abefa46-c530-486c-9749-beca979852f9"])

```

---

Added to `cartodb/config/app_config.yml`:

```bash
varnish_management:
    critical: false
    host: '127.0.0.1'
    port: 6082
    purge_command: 'purge'
    url_purge_command: 'url.purge'
    retries: 5
    timeout: 5
```

Imports still fail.

---

Added to `cartodb/script/resque`:

```bash
RAILS_ENV=production
```

So it looks like:

```bash
VVERBOSE=true QUEUE=* RAILS_ENV=production rake environment resque:work
```

Imports still fail.


---

Trying to alter the Windshaft config to account for subdomainless, that may be causing the failure. I noticed that while I am able to get to `http://<our-ip>:8080/user/dan/API/v1/version` (the SQL-API url) I can't get to `http://<our-ip>:8181/user/dan/version` (the Windshaft url).

Changing:

```bash
,user_from_host: '^(.*)\\.cartodb\\.com$'
```

To:

```bash
,user_from_host: '^<our-ip>:8181\/user\/(.*)$'
```

Not sure if the regex is right, or is this is even the issue.

---

Got our DNS name, and changed all the subdomainless stuff back.

Changed in `cartodb/config/app_config.yml` lines 218-219:
```bash
  cartodb_com_hosted: false
  cartodb_central_domain_name: 'maps.our.company.com'
```

---

The API's weren't able to grab the username out of the domain, so I had to tweak the regex that does the matching. The default setup for cartodb.com is

```bash
'^(.*)\\.cartodb\\.com$';
```

I had to make it

```bash
'^(.*)\\.maps\\.our\\.company\\.com'
```

Note the removal of the `$` from the end. Not sure why, but it was unable to make the match until I removed it. I assume it has to do with our sub-sub-subdomain DNS name.

Now I'm getting a database conn error with the API calls, that's next.

---

I'm changing the password for the `publicuser` user in postgres to 'apiuser'.

---

Changing windshaft config:

```bash
,millstone: {
    // Needs to be writable by server user
    cache_basedir: '/home/ubuntu/tile_assets/'
}
```

to:

```bash
,millstone: {
    // Needs to be writable by server user
    cache_basedir: '/wherever/cartodb/tile_assets'
}
```

---

I cracked it!

Turns out that I configured postgresql to use the preferred development port (5432) but all the production configs are looking for it on 6432. I changed all the configs to 5432 and BOOM everything works!

...almost. There was one remaining issue, but it was an easy one. It seems that the production config tries to load map tiles from a CDN that CartoDB has set up, and which is obviously not *our* CDN, so tiles weren't loading. I found the ` cdn_url` config block in `cartodb/app_config.yml` which was calling out the url of the CartoDB CDN. A little bit of googling later, long story short, setting the urls to empty strings in the config file makes the app not try the CDN load. And, now, datasets and tiles load.

---

The only remaining issue is getting the API's to load over https. This is still causing Chrome warnings about mixed content -- including embedded maps -- and I don't think it will be resolved until everything works over https.

---

## Creating users

In terminal:

```bash
cd /wherever/cartodb
RAILS_ENV=production bundle exec rake cartodb:db:create_user SUBDOMAIN='dan' EMAIL='dan@dan.com' PASSWORD='yay-maps!'
```

---


## Upgrading user accounts

As I found in the initial development setup, the CartoDB project comes configures out-of-the-box as a free account with all fancy features turned off. Here's how to turn them on.

### Sync tables

```bash
# current = 'f'
UPDATE users SET sync_tables_enabled = 't';
```

Then, don't forget to add a call to the update rake task to the crontab

```bash
*/15 * * * *    username  cd /wherever/cartodb && RAILS_ENV=development bundle exec rake cartodb:sync_tables
```

### Table quota

```bash
# current = 5
UPDATE users SET table_quota = 200;
```

### Private tables

```bash
# current = f
UPDATE users SET private_tables_enabled = 't';
```

### Maximum layers

```bash
# current = 4
# 10 layers may affect performance...
UPDATE users SET max_layers = 10;
```

---

## Calling CartoDB base maps over HTTPS

Since we're using SSL to serve the site, any API calls & includes must also be HTTPS to avoid a mixed content warning in the browser. By default, `cartodb/config/app_config.yml` has the HTTP URLs for the base maps hard-coded, and these must be updated. I found a page specifying the HTTPS URLS here: [https://cartodb.com/basemaps/](https://cartodb.com/basemaps/) (about 2/3 down the page).

Example:

```yml
# HTTP
url: 'http://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png'

# change to this HTTPS URL
url: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_nolabels/{z}/{x}/{y}.png'
```

---

## Configuring tiler & sql APIs for SSL

The big remaining issue to resolve is the API calls made by the CartoDB Rails client being made over http. The Windhsaft and SQL-API node.js servers need to be configured for SSL.

In the `Windshaft/config/environments/production.js` file, there is an options block that is passed to the HTTP/HTTPS server creation call, and I think this is where I need to specify our cert & key. In `Windshaft/config/environments/production.js`:

```js
// top of file
var fs = require('fs');

...

,httpAgent: {
    keepAlive: true,
    keepAliveMsecs: 1000,
    maxSockets: 25,
    maxFreeSockets: 256,
    key: fs.readFileSync('/path/to/our/key.key'),
    cert: fs.readFileSync('/path/to/our/cert.crt')
}
```

And in `cartodb/config/app_config.yml`

```yml
tiler:
  filter: 'mapnik'
  internal:
    protocol:      'https'
    domain:        'maps.our.company.com'
    port:          '8181'
    host:          ''
    verifycert:     false
  private:
    protocol:      'https'
    domain:        'maps.our.company.com'
    port:          '8181'
    verifycert:     false
  public:
    protocol:      'https'
    domain:        'maps.our.company.com'
    port:          '8181'
    verifycert:     false
```

This alone doesn't work.

---

Ok, I have an idea.

  - I'm going to configure Apache to listen for the SQL-API and tiler API on ports 9090 and 9191, respectively.
  - I'll change the CartoDB `app_config.yml` to yell at the APIs on those ports, instead of 8080 and 8181
  - I'll install the Apache proxy module as outlined [here](https://www.digitalocean.com/community/tutorials/how-to-use-apache-http-server-as-reverse-proxy-using-mod_proxy-extension)
  - In the newly-created Apache vhost configs for 9090 and 9191, I'll forward (or *proxy*) them to the actual node.js apps on 8080 and 8181, over plain HTTP.
  - Profit?

---

Using Apache's `mod_proxy` has successfully enabled offsetting the API ports and letting Apache deal with the SSL decryption. However, this broke imports. I had to add another directive to the Apache config block to explicitely retain the header & full domain of the request, so that the subdomain/username isn't scraped off. Here are the proxy blocks from `etc/apache2/sites-enabled/cartodb.conf`:

```bash
Listen 9090

NameVirtualHost *:9090

<VirtualHost *:9090>
    ServerName maps.our.company.com

    DocumentRoot /wherever/cartodb/public

    SSLEngine on

    SSLCertificateFile /etc/apache2/certs/our-cert.cer
    SSLCertificateKeyFile /etc/apache2/certs/our-key.key

    # this preserves original header and domain
    ProxyPreserveHost On

    # hardcoded for now, need to fix
    ProxyPass / http://dan.maps.our.company.com:8080/
    ProxyPassReverse / http://dan.maps.our.company.com:8080/

    ProxyPass / http://matt.maps.our.company.com:8080/
    ProxyPassReverse / http://matt.maps.our.company.com:8080/
</VirtualHost>


Listen 9191

NameVirtualHost *:9191

<VirtualHost *:9191>
    ServerName maps.our.company.com

    DocumentRoot /wherever/cartodb/public

    SSLEngine on

    SSLCertificateFile /etc/apache2/certs/our-cert.cer
    SSLCertificateKeyFile /etc/apache2/certs/our-key.key

    # this preserves original header and domain
    ProxyPreserveHost On

    # hardcoded for now, need to fix
    ProxyPass / http://dan.maps.our.company.com:8181/
    ProxyPassReverse / http://dan.maps.our.company.com:8181/

    ProxyPass / http://matt.maps.our.company.com:8181/
    ProxyPassReverse / http://matt.maps.our.company.com:8181/
</VirtualHost>
```

Unfortunately, importing datasets is still broken. The CartoDB team uses nginx; time to trash Apache...

---

### Let's give nginx a shot

First, [disable & turn off Apache](http://askubuntu.com/a/170645/422650):

```bash
# we can turn it back on with
# sudo update-rc.d apache2 enable
sudo update-rc.d apache2 disable
sudo service apache2 stop
```

Then, [walk through the passenger + nginx install](https://www.phusionpassenger.com/library/walkthroughs/deploy/ruby/ownserver/nginx/oss/precise/install_passenger.html).

According to [this page](https://support.ssl.com/Knowledgebase/Article/View/19/0/der-vs-crt-vs-cer-vs-pem-certificates-and-how-to-convert-them), our cert came as DER-encoded, and nginx doesn't like DER-encoded certs. Re-encode [like this](http://serverfault.com/a/535201/310240).


Next, I'll try the reverse proxy setup as outlined [here](http://serverfault.com/questions/171678/nginx-config-front-end-reverse-proxy-to-another-port).

---

That doesn't seem to be re-routing the API calls proeprly. Next, I'll try the nginx config found [here](https://github.com/lordlinus/cartodb/blob/master/nginx.conf).

---

Okay, nginx is serving the site and is attached to the tiler & sql APIs via reverse proxy. Here is `/etc/nginx/sites-enabled/cartodb.conf`

```
server {
    listen 80;
    server_name maps.our.company.com;

    # Tell Nginx and Passenger where your app's 'public' directory is
    root /wherever/cartodb/public;

    # Turn on Passenger
    passenger_enabled on;
    passenger_ruby /wherever/.rbenv/versions/1.9.3-p551/bin/ruby;
}

server {
    listen 443;
    server_name maps.our.company.com;

    # Tell Nginx and Passenger where your app's 'public' directory is
    root /wherever/cartodb/public;

    # Turn on Passenger
    passenger_enabled on;
    passenger_ruby /wherever/.rbenv/versions/1.9.3-p551/bin/ruby;

    ssl on;
    ssl_certificate /etc/ssl/certs/cert-file.pem;
    ssl_certificate_key /etc/ssl/certs/key-file.key;
}

server {
        listen       9090;
        server_name maps.our.company.com;

        ssl on;
        ssl_certificate /etc/ssl/certs/map.apps.hcr-manorcare.pem;
        ssl_certificate_key /etc/ssl/certs/map.apps.hcr-manorcare.key;

        # important, allows proxy connection to use http
        proxy_ssl_session_reuse off;

        location / {
            proxy_pass         http://maps.our.company.com:8080;
            proxy_redirect     off;

            proxy_set_header   Host             $host;
            proxy_set_header   X-Real-IP        $remote_addr;
            proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;

            client_max_body_size       10m;
            client_body_buffer_size    128k;

            proxy_connect_timeout      90;
            proxy_send_timeout         90;
            proxy_read_timeout         90;

            proxy_buffer_size          4k;
            proxy_buffers              4 32k;
            proxy_busy_buffers_size    64k;
            proxy_temp_file_write_size 64k;
        }

}

server {
        listen       9191;
        server_name maps.our.company.com;

        ssl on;
        ssl_certificate /etc/ssl/certs/cert-file.pem;
        ssl_certificate_key /etc/ssl/certs/key-file.key;

        proxy_ssl_session_reuse off;

        location / {
            proxy_pass         http://maps.our.company.com:8181;
            proxy_redirect     off;

            proxy_set_header   Host             $host;
            proxy_set_header   X-Real-IP        $remote_addr;
            proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;

            client_max_body_size       10m;
            client_body_buffer_size    128k;

            proxy_connect_timeout      90;
            proxy_send_timeout         90;
            proxy_read_timeout         90;

            proxy_buffer_size          4k;
            proxy_buffers              4 32k;
            proxy_busy_buffers_size    64k;
            proxy_temp_file_write_size 64k;
        }

}

```



## Long-term service spawning

[This page will eventually hold the process.](SERVER-CONFIG.md)

Starting all the processes with bash from the crontab is super-hacky; just need to power through setting them all up as daemons. Apparently the hip kids are using [Upstart](http://upstart.ubuntu.com/) now instead of traditional init scripts, so that's probably the path to take.
