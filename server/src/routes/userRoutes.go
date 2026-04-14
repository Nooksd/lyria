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
		user.GET("/:userId", controllers.GetOneUser())
		user.PUT("/update/:userId", controllers.UpdateOneUser())
		user.GET("/playlists", controllers.GetOwnPlaylists())
		user.GET("/profile/:userId", controllers.GetUserProfile())
		user.POST("/favorites/:musicId", controllers.ToggleFavorite())
		user.GET("/favorites", controllers.GetFavorites())
	}
	router.POST("/image/avatar", controllers.UploadAvatar())
}
