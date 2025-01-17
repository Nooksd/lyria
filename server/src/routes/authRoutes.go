package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func AuthRoutes(router *gin.Engine) {
	router.POST("/auth/login", controller.LoginUser())
	router.GET("/auth/refresh-token", controller.RefreshToken())
}
