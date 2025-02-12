package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func PlaylistRoutes(router *gin.RouterGroup) {
	playlist := router.Group("/playlist")
	{
		playlist.POST("/create", controller.CreatePlaylist())
		playlist.GET("/:playlistId", controller.GetPlaylist())
		playlist.PUT("/update/:playlistId", controller.UpdatePlaylist())
		playlist.DELETE("/delete/:playlistId", controller.DeletePlaylist())
	}

}
