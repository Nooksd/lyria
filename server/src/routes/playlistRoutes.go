package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func PlaylistRoutes(router *gin.Engine) {
	router.POST("/playlist/create", controller.CreatePlaylist())
	router.GET("/playlist/:playlistId", controller.GetPlaylist())

	router.PUT("/playlist/update/:playlistId", controller.UpdatePlaylist())
	router.DELETE("/playlist/delete/:playlistId", controller.DeletePlaylist())

}
