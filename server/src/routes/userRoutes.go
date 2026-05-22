package routes

import (
	"server/src/controllers"

	"github.com/gin-gonic/gin"
)

func UserRoutes(router *gin.RouterGroup) {
	user := router.Group("/users")
	{
		user.POST("/create", controllers.CreateUser())
		user.GET("/", controllers.SearchUsers())
		user.GET("/me", controllers.GetCurrentUser())
		user.GET("/:userId", controllers.GetOneUser())
		user.PUT("/update/:userId", controllers.UpdateOneUser())
		user.GET("/playlists", controllers.GetOwnPlaylists())
		user.GET("/profile/:userId", controllers.GetUserProfile())
		user.GET("/favorites/albums", controllers.GetFavoriteAlbums())
		user.POST("/favorites/albums/:albumId", controllers.ToggleFavoriteAlbum())
		user.GET("/favorites/artists", controllers.GetFavoriteArtists())
		user.POST("/favorites/artists/:artistId", controllers.ToggleFavoriteArtist())
		user.POST("/favorites/:musicId", controllers.ToggleFavorite())
		user.GET("/favorites", controllers.GetFavorites())
	}
	router.POST("/image/avatar", controllers.UploadAvatar())
	router.GET("/artist-request/search", controllers.SearchSpotifyArtistsForRequest())
	router.POST("/artist-request", controllers.CreateArtistRequest())
}
