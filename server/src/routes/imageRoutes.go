package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func ImageRoutes(router *gin.Engine) {
	router.GET("/avatar/:userId", controller.GetAvatar())
}
