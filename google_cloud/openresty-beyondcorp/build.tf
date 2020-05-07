# Mirror base image from Dockerhub image into Google Container Registry
module "docker-mirror" {
  source      = "github.com/neomantra/terraform-docker-mirror"
  image_name  = local.base_image_name
  image_tag   = local.base_image_tag
  dest_prefix = "eu.gcr.io/${local.project}"
}

# Hydrate docker template file into .build directory
resource "local_file" "dockerfile" {
  content = templatefile("${path.module}/Dockerfile.template", {
    project = local.project
    image   = local.base_image_name
    tag     = local.base_image_tag
    OPM_VERSION = "0.0.5"
    LUA_RESTY_HTTP_VERSION = "1.13.6.2"
    _prefix="/usr/local"
  })
  filename = "${path.module}/.build/Dockerfile"
}

# Build a customized image
resource "null_resource" "openresty_image" {
  depends_on = [module.docker-mirror]
  triggers = {
    # Rebuild if we change the base image, dockerfile, or bpm-platform config
    image = "eu.gcr.io/${local.project}/openresty:${local.base_image_tag}_${
      sha1(
        "${sha1(local_file.dockerfile.content)}${sha1(local_file.config.content)}${sha1(local_file.login.content)}"
      )  
    }"
  }
  provisioner "local-exec" {
    command = <<-EOT
        gcloud builds submit \
        --project ${local.project} \
        --tag ${self.triggers.image} \
        ${path.module}/.build
    EOT
  }
}