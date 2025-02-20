import 'package:lyria/app/modules/bottom_sheet_options/modals/album_modal.dart';
import 'package:lyria/app/modules/bottom_sheet_options/modals/artist_modal.dart';
import 'package:lyria/app/modules/bottom_sheet_options/page/custom_bottom_modals.dart';
import 'package:lyria/app/modules/bottom_sheet_options/modals/music_modal.dart';
import 'package:lyria/app/modules/explorer/domain/entities/search.dart';

CustomModal createModal(Search search) {
  switch (search.type) {
    case 'music':
      return MusicModal(search);
    case 'artist':
      return ArtistModal(search);
    case 'album':
      return AlbumModal(search);
    case 'playlist':
      // return PlaylistModal(search);
    default:
      throw Exception('Tipo de modal não suportado');
  }
}