package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func TesteRoutes(router *gin.Engine) {
	router.POST("/music/create", controller.DownloadAudio())
	router.GET("/stream/:fileName", controller.StreamAudio())
}
