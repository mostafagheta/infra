resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.subnet_ids

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "node_port" {
  for_each = toset([for p in var.node_ports : tostring(p)])

  name        = "${var.project_name}-tg-${each.value}"
  port        = each.value
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    port                = each.value
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.project_name}-tg-${each.value}"
  }
}

# Attach both worker nodes (the "2 local hosts") to every target group
resource "aws_lb_target_group_attachment" "worker" {
  for_each = {
    for pair in setproduct(var.node_ports, range(length(var.worker_instance_ids))) :
    "${pair[0]}-${pair[1]}" => { port = pair[0], idx = pair[1] }
  }

  target_group_arn = aws_lb_target_group.node_port[tostring(each.value.port)].arn
  target_id        = var.worker_instance_ids[each.value.idx]
  port              = each.value.port
}

resource "aws_lb_listener" "node_port" {
  for_each = aws_lb_target_group.node_port

  load_balancer_arn = aws_lb.this.arn
  port               = each.value.port
  protocol           = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = each.value.arn
  }
}
