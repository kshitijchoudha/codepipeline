data "aws_lb_target_group" "tf_ecs_targetgroup" {
  name = "tf-tg-test"
}

resource "aws_ecs_cluster" "tf_ecs" {
  name = "tf_ecs"
}

data "aws_ecs_task_definition" "tf_nginx_service" {
  task_definition = "${aws_ecs_task_definition.tf_nginx_service.family}"
}

resource "aws_ecs_task_definition" "tf_nginx_service" {
  family                   = "tf-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.codepipeline_role.arn

  container_definitions = <<EOF
[{
      "name": "tf-demo-service",
      "image": "800280303592.dkr.ecr.us-east-2.amazonaws.com/nginx:tf-dev",
      "essential": true,
      "portMappings": [
        {
          "hostPort": 80,
          "protocol": "tcp",
          "containerPort": 80
        }
      ],
      "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "awslogs-ecs",
                    "awslogs-region": "us-east-2",
                    "awslogs-stream-prefix": "awslogs-ecs",
                    "awslogs-create-group" : "true"
                }
            }
    }]
    
  EOF
}

resource "aws_ecs_service" "tf_ecs_service" {
  name    = "tf_ecs_service"
  cluster = aws_ecs_cluster.tf_ecs.id
  #task_definition = aws_ecs_task_definition.tf_nginx_service.arn
  task_definition = "${aws_ecs_task_definition.tf_nginx_service.family}:${max("${aws_ecs_task_definition.tf_nginx_service.revision}", "${data.aws_ecs_task_definition.tf_nginx_service.revision}")}"
  desired_count   = 3
  #iam_role        = data.aws_iam_role.codepipeline_role.arn
  #depends_on      = [data.aws_iam_role.codepipeline_role]
  launch_type = "FARGATE"
  deployment_controller {
    type = "CODE_DEPLOY"
  }
  load_balancer {
    target_group_arn = data.aws_lb_target_group.tf_ecs_targetgroup.arn
    container_name   = "tf-demo-service"
    container_port   = 80
  }

  network_configuration {
    security_groups  = ["sg-fbe1299b"]
    subnets          = ["subnet-a6591ddc", "subnet-b15ef2fd"]
    assign_public_ip = "true"
  }
}
