resource "local_file" "ansible_inventory" {
  content  = templatefile("${path.module}/templates/inventory.tmpl", {
    bastion_public_ip = aws_instance.bastion.public_ip
    vote_private_ip   = aws_instance.vote.private_ip
    result_private_ip = aws_instance.result.private_ip
    worker_private_ip = aws_instance.worker.private_ip
    redis_private_ip  = aws_instance.redis.private_ip
    db_private_ip     = aws_instance.db.private_ip
  })
  filename = "${path.module}/../ansible/inventory.ini"
}

output "inventory" {
  value = templatefile("${path.module}/templates/inventory.tmpl", {
    bastion_public_ip = aws_instance.bastion.public_ip
    vote_private_ip   = aws_instance.vote.private_ip
    result_private_ip = aws_instance.result.private_ip
    worker_private_ip = aws_instance.worker.private_ip
    redis_private_ip  = aws_instance.redis.private_ip
    db_private_ip     = aws_instance.db.private_ip
  })
}
