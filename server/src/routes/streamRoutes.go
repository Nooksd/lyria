package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func StreamRoutes(router *gin.Engine) {
	router.GET("/stream/:musicId", controller.StreamMusic())
}
