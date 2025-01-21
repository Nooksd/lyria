package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func MusicJamRoutes(router *gin.Engine) {
	router.POST("/musicjam/create", controller.CreateMusicJam())
	router.GET("/musicjam/join/:simpleId", controller.JoinMusicJam())
	router.GET("/musicjam/leave/:simpleId", controller.LeaveMusicJam())

	router.GET("/musicjam/ws/:simpleId", controller.MusicJamWebSocket())
}
