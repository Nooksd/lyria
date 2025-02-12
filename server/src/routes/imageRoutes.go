package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func ImageRoutes(router *gin.Engine) {
	image := router.Group("/image")
	{
		image.GET("/avatar/:userId", controller.GetAvatar())
		image.GET("/cover/:id", controller.GetCover())
	}
}
