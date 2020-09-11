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