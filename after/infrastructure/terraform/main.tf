terraform {
  required_version = "0.12.23"
}

provider aws {
  region  = var.aws_region
  version = "2.52.0"
}

locals {
  get_movie_lambda_dist_filename           = "../../app/packages/get-movie.zip"
  update_movie_rating_lambda_dist_filename = "../../app/packages/update-movie-rating.zip"
  upload_movie_infos_lambda_dist_filename  = "../../app/packages/upload-movie-infos.zip"
  get_movie_lambda_handler = {
    "java" : "de.mbe.tutorials.aws.serverless.movies.getmovie.FnGetMovie::handleRequest",
    "python" : "get-movie/fn_get_movie.handle_request"
  }
  update_movie_rating_lambda_handler = {
    "java" : "de.mbe.tutorials.aws.serverless.movies.updatemovierating.FnUpdateMovieRating::handleRequest",
    "python" : "update-movie-rating/fn_update_movie_rating.handle_request"
  }
  upload_movie_infos_lambda_handler = {
    "java" : "de.mbe.tutorials.aws.serverless.movies.uploadmovieinfos.FnUploadMovieInfos::handleRequest",
    "python" : "upload-movie-infos/fn_upload_movie_infos.handle_request"
  }
  lambda_runtime = {
    "java" : "java11",
    "python" : "python3.8"
  }
}

############################################################################

module movie_infos_table {
  source        = "./modules/dynamo_db"
  name          = "movie_infos"
  hash_key_name = "movie_id"
}

module movie_ratings_table {
  source        = "./modules/dynamo_db"
  name          = "movie_ratings"
  hash_key_name = "movie_id"
}

############################################################################

module movie_infos_bucket {
  source = "./modules/s3"
  name   = "${var.aws_account_id}-movie-infos"
}

############################################################################

data aws_iam_policy_document iam_assume_role_policy {
  statement {
    effect = "Allow"
    principals {
      identifiers = [
        "lambda.amazonaws.com"
      ]
      type = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data aws_iam_policy_document upload_movie_infos_lambda_iam_policy_document {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      module.movie_infos_bucket.arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectVersion"
    ]
    resources = [
      "${module.movie_infos_bucket.arn}/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      module.movie_infos_table.arn
    ]
  }
}

data aws_iam_policy_document update_movie_rating_lambda_iam_policy_document {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      module.movie_ratings_table.arn
    ]
  }
}

data aws_iam_policy_document get_movie_lambda_iam_policy_document {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [
      module.movie_infos_table.arn,
      module.movie_ratings_table.arn
    ]
  }
}

############################################################################

module upload_movie_infos_lambda_role {
  source                  = "./modules/iam/role"
  role_name               = "upload_movie_infos_lambda_role"
  assume_role_policy_json = data.aws_iam_policy_document.iam_assume_role_policy.json
  policy_name             = "upload_movie_infos_lambda_policy"
  policy_json             = data.aws_iam_policy_document.upload_movie_infos_lambda_iam_policy_document.json
}

module update_movie_rating_lambda_role {
  source                  = "./modules/iam/role"
  role_name               = "update_movie_rating_lambda_role"
  assume_role_policy_json = data.aws_iam_policy_document.iam_assume_role_policy.json
  policy_name             = "update_movie_rating_lambda_policy"
  policy_json             = data.aws_iam_policy_document.update_movie_rating_lambda_iam_policy_document.json
}

module get_movie_lambda_role {
  source                  = "./modules/iam/role"
  role_name               = "get_movie_lambda_role"
  assume_role_policy_json = data.aws_iam_policy_document.iam_assume_role_policy.json
  policy_name             = "get_movie_lambda_policy"
  policy_json             = data.aws_iam_policy_document.get_movie_lambda_iam_policy_document.json
}

############################################################################

module upload_movie_infos_lambda {
  source           = "./modules/lambda"
  function_name    = "${var.code_version}_fn_upload_movie_infos"
  description      = "Read movies from an S3 file and dump them into the DynamoDB table"
  role             = module.upload_movie_infos_lambda_role.arn
  runtime          = local.lambda_runtime[var.code_version]
  handler          = local.upload_movie_infos_lambda_handler[var.code_version]
  filename         = local.upload_movie_infos_lambda_dist_filename
  source_code_hash = filebase64sha256(local.upload_movie_infos_lambda_dist_filename)
  env = {
    MOVIE_INFOS_BUCKET = module.movie_infos_bucket.name
    MOVIE_INFOS_TABLE  = module.movie_infos_table.name
  }
}

module update_movie_rating_lambda {
  source           = "./modules/lambda"
  function_name    = "${var.code_version}_fn_update_movie_rating"
  description      = "Receive a PATCH request from the API GW and save the resource in the DynamoDB table"
  role             = module.update_movie_rating_lambda_role.arn
  runtime          = local.lambda_runtime[var.code_version]
  handler          = local.update_movie_rating_lambda_handler[var.code_version]
  filename         = local.update_movie_rating_lambda_dist_filename
  source_code_hash = filebase64sha256(local.update_movie_rating_lambda_dist_filename)
  env = {
    MOVIE_RATINGS_TABLE = module.movie_ratings_table.name
  }
}

module get_movie_lambda {
  source           = "./modules/lambda"
  function_name    = "${var.code_version}_fn_get_movie"
  description      = "Receive a GET request from the API GW and retreive the resource from the DynamoDB table"
  role             = module.get_movie_lambda_role.arn
  runtime          = local.lambda_runtime[var.code_version]
  handler          = local.get_movie_lambda_handler[var.code_version]
  filename         = local.get_movie_lambda_dist_filename
  source_code_hash = filebase64sha256(local.get_movie_lambda_dist_filename)
  env = {
    MOVIE_INFOS_TABLE   = module.movie_infos_table.name
    MOVIE_RATINGS_TABLE = module.movie_ratings_table.name
  }
}

############################################################################

module movies_api_gw {
  source      = "./modules/api_gateway/rest_api"
  name        = "movies_api"
  description = "This is the API for the Movies project"
}

module movies_resource {
  source      = "./modules/api_gateway/resource"
  rest_api_id = module.movies_api_gw.id
  parent_id   = module.movies_api_gw.root_resource_id
  path_part   = "movies"
}

module movie_resource {
  source      = "./modules/api_gateway/resource"
  rest_api_id = module.movies_api_gw.id
  parent_id   = module.movies_resource.id
  path_part   = "{movieId}"
}

module get_movie_request_method {
  source        = "./modules/api_gateway/method"
  rest_api_id   = module.movies_api_gw.id
  resource_id   = module.movie_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

module update_movie_rating_request_method {
  source        = "./modules/api_gateway/method"
  rest_api_id   = module.movies_api_gw.id
  resource_id   = module.movie_resource.id
  http_method   = "PATCH"
  authorization = "NONE"
}

module get_movie_request_integration {
  source              = "./modules/api_gateway/integration"
  rest_api_id         = module.movies_api_gw.id
  resource_id         = module.movie_resource.id
  http_method         = module.get_movie_request_method.http_method
  function_invoke_arn = module.get_movie_lambda.invoke_arn
  depends_on_method   = module.get_movie_request_method
}

module update_movie_rating_request_integration {
  source              = "./modules/api_gateway/integration"
  rest_api_id         = module.movies_api_gw.id
  resource_id         = module.movie_resource.id
  http_method         = module.update_movie_rating_request_method.http_method
  function_invoke_arn = module.update_movie_rating_lambda.invoke_arn
  depends_on_method   = module.update_movie_rating_request_method
}

module movies_api_deployment {
  source                   = "./modules/api_gateway/deployment"
  rest_api_id              = module.movies_api_gw.id
  stage_name               = "prod"
  depends_on_integration_1 = module.get_movie_request_integration
  depends_on_integration_2 = module.update_movie_rating_request_integration
}

############################################################################

module allow_movies_bucket_to_invoke_upload_movie_infos_lambda {
  source              = "./modules/lambda_permission/allow_execution_from_s3_bucket"
  bucket_arn          = module.movie_infos_bucket.arn
  function_arn        = module.upload_movie_infos_lambda.arn
  depends_on_bucket   = module.movie_infos_bucket
  depends_on_function = module.upload_movie_infos_lambda
}

module movies_bucket_notification {
  source              = "./modules/s3_notification/object_created"
  bucket_id           = module.movie_infos_bucket.id
  function_arn        = module.upload_movie_infos_lambda.arn
  file_extension      = "csv"
  depends_on_function = module.upload_movie_infos_lambda
  depends_on_bucket   = module.movie_infos_bucket
}

############################################################################

module allow_movies_api_gw_to_invoke_get_movie_lambda {
  source              = "./modules/lambda_permission/allow_execution_from_api_gateway"
  region              = var.aws_region
  account_id          = var.aws_account_id
  api_gw_id           = module.movies_api_gw.id
  resource_path       = module.movie_resource.path
  function_arn        = module.get_movie_lambda.arn
  method_http_verb    = module.get_movie_request_method.http_method
  depends_on_function = module.get_movie_lambda
  depends_on_api_gw   = module.movies_api_gw
}

module allow_movies_api_gw_to_invoke_update_movie_rating_lambda {
  source              = "./modules/lambda_permission/allow_execution_from_api_gateway"
  region              = var.aws_region
  account_id          = var.aws_account_id
  api_gw_id           = module.movies_api_gw.id
  resource_path       = module.movie_resource.path
  function_arn        = module.update_movie_rating_lambda.arn
  method_http_verb    = module.update_movie_rating_request_method.http_method
  depends_on_function = module.update_movie_rating_lambda
  depends_on_api_gw   = module.movies_api_gw
}

############################################################################

