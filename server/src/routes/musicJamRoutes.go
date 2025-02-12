package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func MusicJamRoutes(router *gin.RouterGroup) {
	musicJam := router.Group("/musicjam")
	{
		musicJam.POST("/create", controller.CreateMusicJam())
		musicJam.GET("/join/:simpleId", controller.JoinMusicJam())
		musicJam.GET("/leave/:simpleId", controller.LeaveMusicJam())

		musicJam.GET("/ws/:simpleId", controller.MusicJamWebSocket())
	}
}
