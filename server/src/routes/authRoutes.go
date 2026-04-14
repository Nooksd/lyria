package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func AuthRoutes(router *gin.Engine) {
	auth := router.Group("/auth")
	{
		auth.POST("/login", controller.LoginUser())
		auth.POST("/register", controller.RegisterUser())
		auth.POST("/verify-email", controller.VerifyEmail())
		auth.POST("/resend-verification", controller.ResendVerification())
		auth.GET("/refresh-token", controller.RefreshToken())
		auth.POST("/logout", controller.LogoutUser())
	}
}
