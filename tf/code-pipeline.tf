

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "tf-codepipeline-bucket-20200307"
  acl    = "private"
}

data "aws_iam_role" "codepipeline_role" {
  name = "AWSCodePipelineServiceRole-us-east-2-test-pipeline"

  #   assume_role_policy = <<EOF
  # {
  #   "Version": "2012-10-17",
  #   "Statement": [
  #     {
  #       "Effect": "Allow",
  #       "Principal": {
  #         "Service": "codepipeline.amazonaws.com"
  #       },
  #       "Action": "sts:AssumeRole"
  #     }
  #   ]
  # }
  # EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = data.aws_iam_role.codepipeline_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning",
        "s3:PutObject"
      ],
     "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

data "aws_kms_alias" "s3kmskey" {
  name = "alias/myKmsKey"
}

resource "aws_codepipeline" "codepipeline" {
  name     = "tf-test-pipeline"
  role_arn = data.aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = data.aws_kms_alias.s3kmskey.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      run_order        = "1"

      configuration = {
        Owner                = "kshitijchoudha"
        Repo                 = "codepipeline"
        Branch               = "master"
        OAuthToken           = var.github_token
        PollForSourceChanges = "false"
      }
    }
    action {
      name      = "image"
      category  = "Source"
      owner     = "AWS"
      provider  = "ECR"
      run_order = "1"
      version   = "1"
      configuration = {
        ImageTag       = "tf-dev1"
        RepositoryName = "nginx"
      }
      output_artifacts = ["TestImage"]

    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["SourceArtifact", "TestImage"]
      version         = "1"

      configuration = {
        AppSpecTemplateArtifact        = "SourceArtifact"
        AppSpecTemplatePath            = "appspec.yaml"
        ApplicationName                = "cd-test"
        DeploymentGroupName            = "cd-test-deploy-group"
        Image1ArtifactName             = "TestImage"
        Image1ContainerName            = "IMAGE1_NAME"
        TaskDefinitionTemplateArtifact = "SourceArtifact"
        TaskDefinitionTemplatePath     = "taskdef.json"
      }

    }
  }
}
