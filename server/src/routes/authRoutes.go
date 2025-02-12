package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func AuthRoutes(router *gin.Engine) {
	auth := router.Group("/auth")
	{
		auth.POST("/login", controller.LoginUser())
		auth.GET("/refresh-token", controller.RefreshToken())
		auth.POST("/logout", controller.LogoutUser())
	}
}
