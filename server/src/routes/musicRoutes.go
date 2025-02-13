package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func MusicRoutes(router *gin.RouterGroup) {
	artist := router.Group("/artist")
	album := router.Group("/album")
	music := router.Group("/music")

	{
		artist.POST("/create", controller.CreateArtist())
		artist.GET("/:artistId", controller.GetArtist())
		artist.PUT("/update/:artistId", controller.UpdateArtist())
		artist.DELETE("/delete/:artistId", controller.DeleteArtist())
	}
	{
		album.POST("/create", controller.CreateAlbum())
		album.GET("/:albumId", controller.GetAlbum())
		album.PUT("/update/:albumId", controller.UpdateAlbum())
		album.DELETE("/delete/:albumId", controller.DeleteAlbum())
	}
	{
		music.POST("/create", controller.CreateMusic())
		music.PUT("/update/:musicId", controller.UpdateMusic())
		music.DELETE("/delete/:musicId", controller.DeleteMusic())
	}

	router.GET("/search", controller.GeneralSearch())
}
