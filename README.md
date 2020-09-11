# Larabref

This repo is an example of a laravel application deployed with [bref](https://bref.sh). It has auth, a db and email.

The guide below explains how to create something similar for yourself

- [Larabref](#larabref)
  - [Foreword](#foreword)
    - [What we will try to achieve](#what-we-will-try-to-achieve)
    - [Notes](#notes)
    - [Assumptions](#assumptions)
  - [Stage 1 - AWS Set up](#stage-1---aws-set-up)
  - [Stage 2 - Laravel set up](#stage-2---laravel-set-up)
  - [Stage 3 - View the welcome page on a live server](#stage-3---view-the-welcome-page-on-a-live-server)
  - [Stage 4 - Add styling and store assets appropriately](#stage-4---add-styling-and-store-assets-appropriately)
  - [Stage 5 - Use docker for local development](#stage-5---use-docker-for-local-development)
  - [Stage 6 - Use a makefile](#stage-6---use-a-makefile)
  - [Stage 7 - Connect your domain name](#stage-7---connect-your-domain-name)
  - [Stage 8 - The database](#stage-8---the-database)
  - [Stage 9 - Send verification email - in development](#stage-9---send-verification-email---in-development)
  - [Stage 10 - Send verification email - in production](#stage-10---send-verification-email---in-production)
  - [Epilogue](#epilogue)

## Foreword

I like the idea of deploying laravel serverlessly because it will be easier and quicker to deploy, potentially cheaper and more secure.

But I can't afford [Vapor](https://vapor.laravel.com/), so I decided to use Bref.

Now, the bref site gives quite extensive advice about how to use laravel with bref, and [mnapoli](https://github.com/mnapoli) gives several examples of laravel with bref including [this one](https://github.com/mnapoli/bref-laravel-demo).but it still took me a while to work out how to put all the pieces together successfully.

So in this guide I will give a step by step overview of how to set up a standard laravel installation with bref that includes email and auth.

### What we will try to achieve

We will set up a laravel web application using bref on aws. However, I do not judge simply being able to see the world "Laravel" on a live web page sufficient - we need a functioning web app. 

Our criteria for a successful serverless laravel application will therefore be slightly more ambitious. It will:

* Start with the default laravel css but switch to use tailwind css
* Have a database connection
* Have an authentication system
* Send email (using aws ses) so user can verify their sign up email
* Have a real domain and and an ssl cert
* Be available at both the naked domain and www.domain
* Redirect http to https

As far as possible we will use aws services to achieve the above. However, there are two exceptions in this guide:

1. Since I find aws RDS too expensive and the pricing is unpredictable I will use a digital ocean mysql cluster instead. To use aws rds the steps are similar and not too hard to work out. Previously I used aurora serverless.
2. Since I already own several domains that are not on aws and transferring them in to aws costs money I will use my own domain in this guide. Using a domain set up on route 53 is relatively easy, so again, you can figure it out yourself...

### Notes
> This guide contains various example passwords and other secrets - these are either all fake or have been disposed of before this guide was published.

> In this guide I will use the project name 'larabref', so you should replace this with your own name.

### Assumptions

This guide assumes the following:

1. You are familiar with github, laravel, docker and php.
2. You understand what [serverless](https://www.serverless.com/) and [bref](https://www.bref.sh/) are - if not just read the web pages to get an overview. You don't need to understand either in detail.
3. You have the following software installed locally:
   1. node
   2. npm
   3. php 7+
   4. composer
   5. git


## Stage 1 - AWS Set up

Firstly, we need to connect our local machine to our aws account.

1. If you haven't already got one, create an aws account and IAM user with general permissions (eg admin). Full details [here.](https://docs.aws.amazon.com/polly/latest/dg/setting-up.html)

2. Create an access key and secret access key for the user and save it somewhere sensible (like your password manager).

3. Install aws cli on your local machine and run `aws configure` to add the credentials you saved above in step 3. [Full info here.](https://aws.amazon.com/cli/)

6. Install aws sam on your local machine. Full instructions [here.](https://aws.amazon.com/serverless/sam/)

7. Run `npm install -g serverless`. This installs the serverless framework

## Stage 2 - Laravel set up

Now we need to set up a basic laravel project

1. Run `composer create-project laravel/laravel=7.28.0 larabref --prefer-dist`
2. Create a new repo on github with the name of your project.
3. Push your local copy up to origin (change the repo name...) `cd larabref && git init && git remote add origin https://github.com/jimtaylor123/larabref.git && git add . && git commit -m 'initial commit' && git push -u origin master`

4. Optional - install prestissimo to speed up composer installs - `composer global require hirak/prestissimo`.

5. Run `composer install`.
   
6. Customise your .env.example file - change the APP_NAME and APP_URL to the ones you are using.

7.  Run `cp .env.example .env && php artisan key:generate`

8.  Run `mkdir .env_files && mv .env.example .env_files && cp .env .env_files/.env.dev && cp .env .env_files/.env.prod` This will create a directory of .env files for you to use. 
9.  However, you probably don't want to commit the production env values, so add to your .gitignore file 
```git
.env_files/.env.prod
```

11. Test your install by running command `php artisan serve` and visiting `localhost:8000` - you should see the laravel welcome page
12. Press ctrl+c to stop the php server

## Stage 3 - View the welcome page on a live server

Now, lets deploy our laravel application as a real live website.

1. Run `composer require bref/bref bref/laravel-bridge && php artisan vendor:publish --tag=serverless-config`
2. customise the serverless file - change the service name to the name of your app
3. Add .serverless/ to your .gitignore file
4. Run on aws: `serverless deploy` - you will now see the laravel page on the url produced in the cli (not the one ending in {proxy+})
5. Redeploy with a change - open the welcome blade and change laravel to your name and then `sls deploy` (sls is alias for serverless).

## Stage 4 - Add styling and store assets appropriately

Lets use the user friendly css framework, tailwind. Since our serverless app doesn't have any public folders, we will establish a way to save our public files to s3.

1. Switch to tailwind css - run `composer require laravel/ui && composer require laravel-frontend-presets/tailwindcss ^4.1.0`
2. Add auth routes: `php artisan ui tailwindcss --auth`
3. In the file welcome.blade.php we need to change line 14 from
   ```php 
   link href="{{ mix('css/app.css') }}" rel="stylesheet">
   ```
   to 
   ```php
   <link href="{{ asset('css/app.css') }}" rel="stylesheet">
   ```
   From now on, whenever you need to reference assets, use the asset() syntax.
4. In .env .env.example and .env.prod add the following two lines, swapping the name larabref for your project name: 
   ```env
    ASSET_URL=https://larabref-public.s3.amazonaws.com
    MIX_ASSET_URL="${ASSET_URL}"
   ```
5. Compile `npm install && npm run dev`
6. Serve `php artisan serve` and check your site looks good.
7. Log in to aws and manually create an s3 bucket for your site assets (the things that normally go in the laravel public folder). Call it something like 'larabref-public'. Make sure to:
   1. Create the bucket in us-east-1 - or the same region as in your serverless.yml file
   2. Make the bucket completely public.
8. Before we deploy this to aws, we need to do two things - make our assets into a production format and then sync them to s3. The command is like this, but edit the name of your bucket:
    `npm run prod && aws s3 sync public/ s3://larabref-public/ --delete --exclude index.php --acl public-read`
9.  Finally, deploy all your new code up to aws `sls deploy`

## Stage 5 - Use docker for local development

You'll be making lots of changes to your app and need a reliable dev environment as close as possible to production. Lets use docker compose.

1. You should have already installed docker when you installed aws sam, but if not for some reason then now install docker on your local machine. 
2. Create a docker compose file `touch docker-compose.yml`
3. Paste the following code in, and make sure the indentation is all correct: 
   
```docker-compose

 version: "3.5"

 services:
     web:
         image: bref/fpm-dev-gateway
         ports:
             - '5000:80'
         volumes:
             - .:/var/task:ro
             - ./cache:/var/task/cache
         depends_on:
             - php
         environment:
             HANDLER: public/index.php
             DOCUMENT_ROOT: public
     php:
         image: bref/php-74-fpm-dev
         volumes:
             - .:/var/task
     
```
4. Now run `docker-compose up -d` and `npm run watch` and visit localhost:5000 to see your app. 
5. This is a superior way to work locally with your application - it ensures we are using the same version of php and any other dependencies and also gives us various other benefits of using a docker environment. We don't have to keep restarting php artisan serve. 
6. To run a command within your docker compose set up, do it like this `docker-compose run php ls`. Whatever comes after 'php' is your command. Here is another example: `docker-compose run php php artisan list`.
7. To stop your local application run `docker-compose down`

## Stage 6 - Use a makefile 

There are too many commands to remember - we need to make life easier and avoid mistakes using a makefile.

1. Install make on your system - some details for mac [here](https://stackoverflow.com/questions/10265742/how-to-install-make-and-gcc-on-a-mac#:~:text=Open%20%22Terminal%22%20(it%20is,to%20the%20Terms%20of%20Service.) and details for windows [here.](https://stackoverflow.com/questions/32127524/how-to-install-and-use-make-in-windows)
   
2. Create a Makefile - `touch Makefile`
   
3. Paste the following into your Makefile, but customise the name of the s3 bucket:

```perl
 aws-up:
	npm run prod
	aws s3 sync public/ s3://larabref-public/ --delete --exclude index.php --acl public-read
	cp .env_files/.env.prod .env
	composer install --prefer-dist --optimize-autoloader --no-dev
	php artisan config:clear
	serverless deploy
aws-down: 
	serverless remove
local-up: 
	composer install
	cp .env_files/.env.dev .env
	npm run dev 
	docker-compose up -d
local-down: 
	docker-compose down
```

4. Run `make aws-up` 
5. Click on the url produced by the command line. You should now see your laravel application online.
6. Remove your application by running `make aws-down`
7. Now we only need to remember 4 commands, not dozens.

## Stage 7 - Connect your domain name

Our app is being served on a randomly generated domain. This is useless for real life. We now need to connect our domain name to our serverless deployment.

1. Buy a domain name if you don't already have one.
2. Go to https://console.aws.amazon.com/acm/home?region=us-east-1#/wizard/ to create an ssl cert
3. Add both your naked domain and www domain using the "add domain names" form, e.g add both www.larabref.com and larabref.com
4. Select dns validation
5. Add the cname records given to your domain
6. Wait for both of your domains to be approved by amazon
7. Open api gateway custom domain page: https://console.aws.amazon.com/apigateway/main/publish/domain-names?region=us-east-1
8. Hit "create". 
9.  Enter the naked domain
10. In the "End point type" select "Edge optimized"
11. Choose the acm certificate from the dropdown that corresponds to your domain.
12. Save.
13. Repeat this process for your www domain.
14. You should now have two "custom domain names". For each one, add an "API mapping" using the form at the bottom right of the screen ("Configure API mappings").
15. Select the api endpoint (called something like "dev-mysite (REST - 4jsdfs99)") and the stage "dev". Leave the path field empty. Save.
16. Do this for both the naked domain and the www domain.
17. For each domain you will now have a "API Gateway domain name" shown. Using each of these create a CNAME record on your domain's dns records pointing the domain (either www or naked) to the relevant "API Gateway domain name".
18. Make sure your sites are up - `make aws-up`
19. Wait for dns to be able to resolve these names - you should see your site when navigating to them.
20. Also check that http redirects to https.

## Stage 8 - The database

1. If you don't already have one, create a digital ocean account.
2. Log in to digital ocean.
3. Create a mysql database cluster.
4. Get the connection info. It will look something like this:
   <img src="dbcon.png"
     alt="DB connection details"
     style="float: left; margin-right: 10px;" />
5. Download the CA Certificate and move it to a directory in your project called .ssl. You may wish to add this to your .gitignore file.
6. Using a db tool (like tablesplus or sequelpro) create a new db for your app in your digital ocean cluster. I will call mine 'comments'.
7. Also create one on your local machine for development.
8. Put all the relevant digital ocean connection details into your .prod.env file and the details for your local db in your .dev.env file.
9. Add the following to your .prod.env file `MYSQL_ATTR_SSL_CA=./.ssl/ca-certificate.crt`
10. For some reason the password reset migration that comes out of the box with laravel doesn't have an id column, so we need to add one to make the first migration work on digital ocean, which requires that all tables have a primary id. Edit the file to add the following line:
    ```php
     public function up()
    {
        Schema::create('password_resets', function (Blueprint $table) {
            $table->string('email')->index();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });
    }
    ```
    should be changed to 
       ```php
     public function up()
    {
        Schema::create('password_resets', function (Blueprint $table) {
            $table->id();
            $table->string('email')->index();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });
    }
    ```
11. Run `local-up` and then run a command within your docker container like this: `docker-compose run php php artisan migrate`. If all is well then you will successfully migrate your users table etc.  
12. Now run the same migration in production - `make aws-up` and then `vendor/bin/bref cli larabref-dev-artisan -- migrate --force` (replace larabref with the name at the top of your serverless file). You should see successful migration output in your cli.
13. Using your desktop sql tool (eg tables plus) you should now see all the tables successfully created. 
14. In your front end register a new user, you should be logged in successfully - this proves you can write to and read from your mysql db. Check your db - the new user should be there.

## Stage 9 - Send verification email - in development
It would be nice to enable email verification for new users.

1. Lets set up mail and queue on dev first - register for an account with mailtrap
2. Go into the config for the demo inbox you see
3. Edit your .dev.env replacing the mail options with those below, replaceing the values for username, password and mail from address:
   ```env
    MAIL_MAILER=smtp
    MAIL_HOST=smtp.mailtrap.io
    MAIL_PORT=2525
    MAIL_USERNAME=dd68ac9c2fbd90
    MAIL_PASSWORD=6074bf5d6d4a76
    MAIL_ENCRYPTION=tls
    MAIL_FROM_ADDRESS=me@mydomain.com
    MAIL_FROM_NAME="${APP_NAME}"
   ```
4. Now edit your web.php file - replace 
   
   ```php
   Route::get('/', function () {
    return view('welcome');
    });
   Auth::routes();
   ```
   
   with
   
   ```php
    Route::get('/', function () {
        return view('welcome');
    });
  
    Auth::routes(['verify' => true]);
   ```

5. Edit your User.php model, add `implements MustVerifyEmail` to the class
6. Edit the Homecontroller.php - make changes: 
   from

   ```php
     public function __construct()
    {
        $this->middleware(['auth']);
    }
   ```

   to  

   ```php
     public function __construct()
    {
        $this->middleware(['auth', 'verified']);
    }
   ```

7. Instead of the above change (which affects all routes in a controller) you can apply password verification to just one route like this:
   ```php
   Route::get('/home', 'HomeController@index')->name('home')->middleware('verified');
   ```
   or to a group of routes like this:
   ```php
    Route::group(['middleware' => ['verified']], function () {
        Route::get('/home', 'HomeController@index')->name('home');
    });
   ```
8. Run `make local-up` and then try and register a new user. Your registration should be successful, but you will be presented with a view asking you to verify. 
9.  Go to mailtraip.io and look in your demo inbox - there should be an email asking you to verify with a button - click it.
10. You should now be able to see the normal welcome after login view.

## Stage 10 - Send verification email - in production

 Now we will set up aws sns to handle our emails in production, not mailtrap (although you could use mailtrap for production - we are just using sns here to show how to use aws services).

1. If you do not already have one, get an inbox for at least one address on your domain. For example, if you have the domain mysite.com then you will need an inbox for something like hi@mysite.com. If you need a free inbox I think zoho is the only company that still offers this. 
   
2. Go to aws ses and add your domain and the email address you want to send email as. You will have to add some records on your dns records. 
   
3. If the email you want to send from your application as is different to your inbox email address (eg bot@app.com and john@app.com) then set up the former as an alias of the latter on your mail settings with your mail provider (you could set up a catch all email address). 
   
4. Install two packages: ```composer require guzzlehttp/guzzle``` and ```composer require aws/aws-sdk-php```

5. In aws console go to ses > smtp settings and go through the steps give to retrieve your username and password.
6. In your .prod.env file change the following values. Use the details given on the smtp credentials page instead of those given below...
   ```env
    MAIL_MAILER=ses
    MAIL_HOST=email-smtp.us-east-1.amazonaws.com
    MAIL_PORT=25
    MAIL_USERNAME=AKIASXWEKEPIPLBWSI*U
    MAIL_PASSWORD=BMf19hN/S2F3WYIsU5cJaS5bGe8Rnso4CNEsCltPy9J&
    MAIL_ENCRYPTION=tls
    MAIL_FROM_ADDRESS=jim@mysite.net
    MAIL_FROM_NAME="${APP_NAME}"

    AWS_ACCESS_KEY_ID=AKIAFDWEKEPIEHCSGJGG
    AWS_SECRET_ACCESS_KEY=wsNDN7XSXXxQK0CA7l9UnQGZfNf5nAKl9Ti+PW^&
    AWS_DEFAULT_REGION=us-east-1
    AWS_BUCKET=
    ```
7. Deploy your code with ```make aws-up``` and register as a new user to see if your email will work - check the inbox of the email you use and verify your sign up - all good! 

## Epilogue

Don't forget to commit your changes and push to github. 
Also, don't forget to remove your deployment if you don't want to continue paying amazon for it - `make aws-down`.

There is more you could do with this project - you might want to add an ephemeral queue for each deployment, and you can even try and automate the domain section. But for this guide this is enough for most of my needs.