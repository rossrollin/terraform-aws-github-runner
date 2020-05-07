resource "aws_lambda_function" "scale_runners_lambda" {
  filename         = "${path.module}/lambdas/scale-runners/scale-runners.zip"
  source_code_hash = filebase64sha256("${path.module}/lambdas/scale-runners/scale-runners.zip")
  function_name    = "${var.environment}-scale-runners"
  role             = aws_iam_role.scale_runners_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs12.x"

  environment {
    variables = {
      ENABLE_ORGANIZATION_RUNNERS = var.enable_organization_runners
      GITHUB_APP_KEY_BASE64       = var.github_app_key_base64
      GITHUB_APP_ID               = var.github_app_id
      GITHUB_APP_CLIENT_ID        = var.github_app_client_id
      GITHUB_APP_CLIENT_SECRET    = var.github_app_client_secret
    }
  }
}

resource "aws_lambda_event_source_mapping" "scale_runners_lambda" {
  event_source_arn = var.sqs.arn
  function_name    = aws_lambda_function.scale_runners_lambda.arn
}

resource "aws_lambda_permission" "scale_runners_lambda" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_runners_lambda.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = var.sqs.arn
}

resource "aws_iam_role" "scale_runners_lambda" {
  name               = "${var.environment}-action-scale-runners-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.environment}-lamda-runners-logging-policy"
  description = "Lambda logging policy"

  policy = templatefile("${path.module}/policies/lambda-cloudwatch.json", {})
}

resource "aws_iam_policy_attachment" "scale_runners_lambda_logging" {
  name       = "${var.environment}-logging"
  roles      = [aws_iam_role.scale_runners_lambda.name]
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "scale_runners_lambda" {
  name        = "${var.environment}-lamda-scale-runners-sqs-receive-policy"
  description = "Lambda webhook policy"

  policy = templatefile("${path.module}/policies/lambda-scale-runners.json", {
    sqs_arn = var.sqs.arn
  })
}

resource "aws_iam_policy_attachment" "scale_runners_lambda" {
  name       = "${var.environment}-scale-runners"
  roles      = [aws_iam_role.scale_runners_lambda.name]
  policy_arn = aws_iam_policy.scale_runners_lambda.arn
}
