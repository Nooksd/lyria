package main

import (
	"log"
	"os"
	"server/src/routes"

	"github.com/gin-gonic/gin"
)

func main() {
	port := os.Getenv("PORT")

	if port == "" {
		port = "8080"
	}

	router := gin.New()
	router.Use(gin.Logger())

	routes.MusicRoutes(router)

	routes.ImageRoutes(router)
	routes.AuthRoutes(router)
	routes.UserRoutes(router)

	// routes.ArtistRoutes(router)
	// routes.AlbumRoutes(router)
	// routes.MusicRoutes(router)

	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Erro ao iniciar o servidor: %v", err)
	}

	log.Println("port", port)
}
