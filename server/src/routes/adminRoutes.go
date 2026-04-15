package routes

import (
	controller "server/src/controllers"

	"github.com/gin-gonic/gin"
)

func AdminRoutes(router *gin.Engine) {
	admin := router.Group("/admin")
	{
		admin.POST("/login", controller.AdminLogin())
	}

	adminProtected := router.Group("/admin")
	adminProtected.Use(controller.AdminAuthMiddleware())
	{
		adminProtected.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "ok"})
		})

		// Artists
		adminProtected.POST("/artist/create", controller.CreateArtist())
		adminProtected.GET("/artist/:artistId", controller.GetArtist())
		adminProtected.PUT("/artist/update/:artistId", controller.UpdateArtist())
		adminProtected.DELETE("/artist/delete/:artistId", controller.DeleteArtist())

		// Albums
		adminProtected.POST("/album/create", controller.CreateAlbum())
		adminProtected.GET("/album/:albumId", controller.GetAlbum())
		adminProtected.PUT("/album/update/:albumId", controller.UpdateAlbum())
		adminProtected.DELETE("/album/delete/:albumId", controller.DeleteAlbum())
		adminProtected.POST("/image/cover/:albumId", controller.UploadCover())

		// Artist images
		adminProtected.POST("/image/artist/:artistId", controller.UploadArtistAvatar())
		adminProtected.POST("/image/banner/:artistId", controller.UploadArtistBanner())

		// Musics
		adminProtected.POST("/music/create", controller.CreateMusic())
		adminProtected.PUT("/music/update/:musicId", controller.UpdateMusic())
		adminProtected.DELETE("/music/delete/:musicId", controller.DeleteMusic())
		adminProtected.POST("/image/music/:musicId", controller.UploadMusicCover())

		// Search
		adminProtected.GET("/search", controller.GeneralSearch())

		// List all
		adminProtected.GET("/artists", controller.ListArtists())
		adminProtected.GET("/albums", controller.ListAlbums())
		adminProtected.GET("/musics", controller.ListMusics())

		// Scoped listing
		adminProtected.GET("/artist/:artistId/albums", controller.ListArtistAlbums())
		adminProtected.GET("/artist/:artistId/musics", controller.ListArtistMusics())
		adminProtected.GET("/album/:albumId/musics", controller.ListAlbumMusics())

		// Spotify import
		adminProtected.GET("/import/spotify", controller.ImportFromSpotify())

		// Import queue
		adminProtected.POST("/import/jobs", controller.CreateImportJobs())
		adminProtected.GET("/import/jobs", controller.ListImportJobs())
		adminProtected.GET("/import/jobs/:jobId", controller.GetImportJob())
		adminProtected.POST("/import/jobs/:jobId/cancel", controller.CancelImportJob())
		adminProtected.GET("/import/jobs/:jobId/logs", controller.StreamImportJobLogs())
	}
}
