package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func MusicRoutes(router *gin.Engine) {
	router.POST("/artist/create", controller.CreateArtist())
	router.GET("/artist/:artistId", controller.GetArtist())
	router.PUT("/artist/update/:artistId", controller.UpdateArtist())
	router.DELETE("/artist/delete/:artistId", controller.DeleteArtist())

	router.POST("/album/create", controller.CreateAlbum())
	router.GET("/album/:albumId", controller.GetAlbum())
	router.PUT("/album/update/:albumId", controller.UpdateAlbum())
	router.DELETE("/album/delete/:albumId", controller.DeleteAlbum())

	router.POST("/music/create", controller.CreateMusic())
	router.GET("/musics", controller.GetAllMusics())
	router.PUT("/music/update/:musicId", controller.UpdateMusic())
	router.DELETE("/music/delete/:musicId", controller.DeleteMusic())

	router.GET("/stream/:artistName/:albumName/:musicName", controller.StreamMusic())
}
