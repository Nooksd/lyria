package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func StreamRoutes(router *gin.RouterGroup) {
	router.GET("/stream/:musicId", controller.StreamMusic())
}
