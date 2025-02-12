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
		user.POST("/avatar/upload", controllers.UploadAvatar())
		user.GET("/:userId", controllers.GetOneUser())
		user.PUT("/update/:userId", controllers.UpdateOneUser())
		user.GET("/playlists", controllers.GetOwnPlaylists())
	}
}
